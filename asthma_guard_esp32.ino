#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include "MAX30100_PulseOximeter.h"
#include <DHT.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "esp_wifi.h"

// ---------------- PINS ----------------
#define DHTPIN 4
#define DHTTYPE DHT22
#define MQ135_PIN 34
#define DUST_PIN 32
#define LED_CONTROL 27
#define BUZZER_PIN 25

// ---------------- FLASK ----------------
const char* FLASK_IP   = "flask_ip";
const int   FLASK_PORT = 5000;
const char* DEV_USER   = "username";
const char* DEV_PASS   = "password";

// ════════════════════════════════════════
//  WIFI CREDENTIALS
//  If password has @ or special chars,
//  hardcode directly — do NOT use #define
// ════════════════════════════════════════
const char* WIFI_SSID = "Airflow";
const char* WIFI_PASS = "air@1234";   // <-- change this if password is different

String jwtToken    = "";
bool flaskOnline = false;

// ---------------- OBJECTS ----------------
LiquidCrystal_I2C lcd(0x27, 16, 2);
PulseOximeter pox;
DHT dht(DHTPIN, DHTTYPE);

// ---------------- GLOBAL VALUES ----------------
float hrFiltered = 75, spo2Filtered = 98;
float temperature = 28, humidity = 60;
float voc = 50, co = 15, no2 = 12, so2 = 10, o3 = 7;
float pm25 = 12, pm10 = 15;
bool fingerDetected = false;
unsigned long lastBeat = 0;
float alpha = 0.3;

// ---------------- DUST FILTER ----------------
#define DUST_SAMPLES 10
float dustBuffer[DUST_SAMPLES];
int dustIndex = 0;

// ---------------- ALERT LIMITS ----------------
#define SPO2_LOW 94
#define HR_HIGH  120
#define HR_LOW   50

// ---------------- HELPERS ----------------
String flaskURL(const char* path) {
  return "http://" + String(FLASK_IP) + ":" + String(FLASK_PORT) + String(path);
}

// ---------------- BUZZER ----------------
void triggerBuzzer(int duration) {
  digitalWrite(BUZZER_PIN, HIGH);
  vTaskDelay(duration / portTICK_PERIOD_MS);
  digitalWrite(BUZZER_PIN, LOW);
}

// ════════════════════════════════════════
//  WIFI CONNECT — Full debug + @ fix
// ════════════════════════════════════════
bool connectWiFi() {
  Serial.println("\n[WiFi] ── Connecting to WiFi ──");
  Serial.printf("[WiFi] SSID     : '%s'\n", WIFI_SSID);
  Serial.printf("[WiFi] Password : '%s'\n", WIFI_PASS);
  Serial.printf("[WiFi] Password length: %d chars\n", strlen(WIFI_PASS));

  // Scan first
  Serial.println("[WiFi] Scanning networks...");
  int n = WiFi.scanNetworks();
  Serial.printf("[WiFi] Found %d networks:\n", n);
  bool found = false;
  for (int i = 0; i < n; i++) {
    bool isTarget = (WiFi.SSID(i) == String(WIFI_SSID));
    if (isTarget) found = true;
    Serial.printf("  [%d] %-25s RSSI:%4d %s\n",
      i + 1,
      WiFi.SSID(i).c_str(),
      WiFi.RSSI(i),
      isTarget ? "<-- TARGET" : ""
    );
  }

  if (!found) {
    Serial.printf("[WiFi] WARNING: '%s' not found!\n", WIFI_SSID);
    Serial.println("[WiFi] Check SSID spelling and 2.4GHz band");
    return false;
  }

  Serial.println("[WiFi] Target network found — attempting connection...");

  // Reset WiFi completely before connecting
  WiFi.disconnect(true);
  WiFi.mode(WIFI_OFF);
  delay(500);
  WiFi.mode(WIFI_STA);
  delay(200);

  // Boost TX power for better connection
  WiFi.setTxPower(WIFI_POWER_19_5dBm);

  // Force 2.4GHz protocols only
  esp_wifi_set_protocol(WIFI_IF_STA,
    WIFI_PROTOCOL_11B | WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N);

  // Connect using const char* directly — avoids #define encoding issues
  WiFi.begin(WIFI_SSID, WIFI_PASS);

  Serial.print("[WiFi] Connecting");
  uint8_t tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 40) {
    delay(500);
    Serial.print(".");
    tries++;
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("[WiFi] ✓ Connected successfully!");
    Serial.printf("[WiFi]   ESP32 IP : %s\n", WiFi.localIP().toString().c_str());
    Serial.printf("[WiFi]   Gateway  : %s\n", WiFi.gatewayIP().toString().c_str());
    Serial.printf("[WiFi]   RSSI     : %d dBm\n", WiFi.RSSI());
    return true;
  }

  // Failed — show exact reason
  int status = WiFi.status();
  Serial.printf("[WiFi] ✗ FAILED — Status: %d\n", status);
  switch (status) {
    case 1:
      Serial.println("[WiFi] Reason: Network name not found");
      break;
    case 4:
      Serial.println("[WiFi] Reason: Wrong password");
      Serial.println("[WiFi] Check your hotspot password carefully");
      Serial.println("[WiFi] Try changing hotspot password to simple one like: asthma1234");
      break;
    case 6:
      Serial.println("[WiFi] Reason: Disconnected");
      break;
    default:
      Serial.println("[WiFi] Reason: Unknown — try restarting hotspot");
      break;
  }
  return false;
}

// ════════════════════════════════════════
//  FLASK LOGIN
// ════════════════════════════════════════
bool loginToFlask() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[Login] WiFi not connected");
    return false;
  }

  Serial.println("[Login] ── Attempting Flask login ──");
  Serial.printf("[Login] URL  : %s\n", flaskURL("/login").c_str());
  Serial.printf("[Login] User : %s\n", DEV_USER);

  HTTPClient http;
  http.begin(flaskURL("/login"));
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(8000);

  String body = "{\"username\":\"" + String(DEV_USER) +
                "\",\"password\":\"" + String(DEV_PASS) + "\"}";

  int code = http.POST(body);
  Serial.printf("[Login] HTTP code: %d\n", code);

  if (code == 200) {
    String resp = http.getString();
    Serial.println("[Login] Response: " + resp);

    StaticJsonDocument<1024> res;
    DeserializationError err = deserializeJson(res, resp);
    if (err) {
      Serial.println("[Login] JSON parse error: " + String(err.c_str()));
      http.end();
      return false;
    }

    const char* token = res["token"];
    if (token && strlen(token) > 10) {
      jwtToken    = String(token);
      flaskOnline = true;
      Serial.println("[Login] ✓ Login SUCCESS");
      http.end();
      return true;
    } else {
      Serial.println("[Login] ✗ No token in response");
    }

  } else if (code == -1) {
    Serial.println("[Login] ✗ Cannot reach Flask server");
    Serial.printf("[Login]   Make sure Flask is running on %s:%d\n", FLASK_IP, FLASK_PORT);
    Serial.println("[Login]   Run on Raspberry Pi: python3 app.py");

  } else if (code == 401) {
    Serial.println("[Login] ✗ Wrong username or password");
    Serial.printf("[Login]   Tried: %s / %s\n", DEV_USER, DEV_PASS);

  } else {
    Serial.printf("[Login] ✗ Unexpected code: %d\n", code);
    Serial.println("[Login]   Response: " + http.getString());
  }

  http.end();
  flaskOnline = false;
  return false;
}

// ════════════════════════════════════════
//  FLASK SEND
// ════════════════════════════════════════
void sendToFlask() {
  // Reconnect WiFi if dropped
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[Flask] WiFi dropped — reconnecting");
    flaskOnline = false;
    connectWiFi();
    if (WiFi.status() != WL_CONNECTED) return;
  }

  // Login if no token
  if (jwtToken.isEmpty()) {
    Serial.println("[Flask] No token — logging in");
    if (!loginToFlask()) return;
  }

  HTTPClient http;
  http.begin(flaskURL("/update_sensor"));
  http.addHeader("Content-Type",  "application/json");
  http.addHeader("Authorization", "Bearer " + jwtToken);
  http.setTimeout(8000);

  StaticJsonDocument<512> doc;
  doc["pm25"]       = round(pm25        * 10)  / 10.0;
  doc["pm10"]       = round(pm10        * 10)  / 10.0;
  doc["no2"]        = round(no2         * 100) / 100.0;
  doc["so2"]        = round(so2         * 100) / 100.0;
  doc["co"]         = round(co          * 100) / 100.0;
  doc["o3"]         = round(o3          * 100) / 100.0;
  doc["temp"]       = round(temperature * 10)  / 10.0;
  doc["humidity"]   = round(humidity    * 10)  / 10.0;
  doc["spo2"]       = fingerDetected ? spo2Filtered : 0;
  doc["heart_rate"] = fingerDetected ? hrFiltered   : 0;

  String body;
  serializeJson(doc, body);
  Serial.println("[HTTP] POST → " + body);

  int code = http.POST(body);
  Serial.printf("[HTTP] Response code: %d\n", code);

  if (code == 200) {
    flaskOnline = true;
    Serial.println("[Flask] ✓ Data sent OK");
    Serial.println("[Flask]   Response: " + http.getString());

  } else if (code == 401) {
    Serial.println("[HTTP] 401 — token expired, re-logging in");
    jwtToken    = "";
    flaskOnline = false;
    http.end();
    delay(500);
    loginToFlask();
    return;

  } else if (code == -1) {
    Serial.println("[HTTP] ✗ Cannot reach Flask");
    Serial.println("[HTTP]   Is Flask running on Raspberry Pi?");
    flaskOnline = false;

  } else {
    Serial.printf("[HTTP] ✗ Error: %d\n", code);
    Serial.println("[HTTP]   Response: " + http.getString());
    flaskOnline = false;
  }

  http.end();
}

// ---------------- MAX30100 TASK ----------------
void TaskMAX30100(void *pvParameters) {
  while (1) {
    pox.update();
    float hr   = pox.getHeartRate();
    float spo2 = pox.getSpO2();
    if (hr > 40 && hr < 220 && spo2 > 85) {
      fingerDetected = true;
      lastBeat     = millis();
      hrFiltered   = alpha * hr   + (1 - alpha) * hrFiltered;
      spo2Filtered = alpha * spo2 + (1 - alpha) * spo2Filtered;
    }
    if (millis() - lastBeat > 3000) fingerDetected = false;
    vTaskDelay(10 / portTICK_PERIOD_MS);
  }
}

// ---------------- SENSOR TASK ----------------
void TaskSensors(void *pvParameters) {
  while (1) {
    float t = dht.readTemperature();
    float h = dht.readHumidity();
    if (!isnan(t)) temperature = t;
    if (!isnan(h)) humidity    = h;

    int   raw     = analogRead(MQ135_PIN);
    float voltage = raw * (3.3 / 4095.0);
    if (voltage < 0.1) voltage = 0.1;
    float Rs    = (3.3 - voltage) / voltage;
    float ratio = Rs / 8.5;
    voc = 116.6 * pow(ratio, -2.76);

    co  = voc * 0.30;
    no2 = voc * 0.25;
    so2 = voc * 0.20;
    o3  = voc * 0.15;

    digitalWrite(LED_CONTROL, LOW);
    delayMicroseconds(280);
    int dustRaw = analogRead(DUST_PIN);
    delayMicroseconds(40);
    digitalWrite(LED_CONTROL, HIGH);
    delayMicroseconds(9680);
    float v    = dustRaw * (3.3 / 4095.0);
    float dust = (170.0 * v) - 0.1;
    if (dust < 0) dust = 0;

    dustBuffer[dustIndex] = dust;
    dustIndex = (dustIndex + 1) % DUST_SAMPLES;
    float sum = 0;
    for (int i = 0; i < DUST_SAMPLES; i++) sum += dustBuffer[i];
    pm25 = sum / DUST_SAMPLES;
    pm10 = pm25 * 1.3;

    vTaskDelay(3000 / portTICK_PERIOD_MS);
  }
}

// ---------------- LCD TASK ----------------
void TaskLCD(void *pvParameters) {
  int screen = 0;
  while (1) {
    lcd.clear();
    if (screen == 0) {
      lcd.setCursor(0, 0); lcd.print("HR:");
      lcd.print(fingerDetected ? (int)hrFiltered : 0);
      lcd.setCursor(0, 1); lcd.print("SpO2:");
      lcd.print(fingerDetected ? (int)spo2Filtered : 0);
    } else if (screen == 1) {
      lcd.setCursor(0, 0); lcd.print("Temp:"); lcd.print(temperature);
      lcd.setCursor(0, 1); lcd.print("Hum:");  lcd.print(humidity);
    } else {
      lcd.setCursor(0, 0); lcd.print("PM2.5:"); lcd.print(pm25);
      lcd.setCursor(0, 1); lcd.print(flaskOnline ? "Flask:ON " : "Flask:OFF");
    }
    screen = (screen + 1) % 3;
    vTaskDelay(2000 / portTICK_PERIOD_MS);
  }
}

// ---------------- ALERT TASK ----------------
void TaskAlert(void *pvParameters) {
  while (1) {
    if (spo2Filtered < SPO2_LOW)                     triggerBuzzer(1000);
    if (hrFiltered > HR_HIGH || hrFiltered < HR_LOW) triggerBuzzer(600);
    vTaskDelay(2000 / portTICK_PERIOD_MS);
  }
}

// ---------------- SERIAL TASK ----------------
void TaskSerial(void *pvParameters) {
  while (1) {
    Serial.println("====== HEALTH DATA ======");
    Serial.print("HR: ");        Serial.println(hrFiltered);
    Serial.print("SpO2: ");      Serial.println(spo2Filtered);
    Serial.print("Finger: ");    Serial.println(fingerDetected ? "YES" : "NO");
    Serial.print("Temp: ");      Serial.println(temperature);
    Serial.print("Humidity: ");  Serial.println(humidity);
    Serial.print("PM2.5: ");     Serial.println(pm25);
    Serial.print("PM10: ");      Serial.println(pm10);
    Serial.print("VOC: ");       Serial.println(voc);
    Serial.print("CO: ");        Serial.println(co);
    Serial.print("NO2: ");       Serial.println(no2);
    Serial.print("SO2: ");       Serial.println(so2);
    Serial.print("O3: ");        Serial.println(o3);
    if      (voc < 100) Serial.println("Air: GOOD");
    else if (voc < 200) Serial.println("Air: MODERATE");
    else                Serial.println("Air: POOR");
    Serial.print("WiFi: ");      Serial.println(WiFi.status() == WL_CONNECTED ? "CONNECTED" : "DISCONNECTED");
    Serial.print("Flask: ");     Serial.println(flaskOnline ? "ONLINE" : "OFFLINE");
    Serial.print("JWT: ");       Serial.println(jwtToken.isEmpty() ? "NONE" : "OK");
    Serial.println("=========================\n");
    vTaskDelay(2000 / portTICK_PERIOD_MS);
  }
}

// ---------------- FLASK TASK ----------------
void TaskFlask(void *pvParameters) {
  vTaskDelay(5000 / portTICK_PERIOD_MS);
  while (1) {
    sendToFlask();
    vTaskDelay(30000 / portTICK_PERIOD_MS);
  }
}

// ════════════════════════════════════════
//  SETUP
// ════════════════════════════════════════
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n╔══════════════════════════╗");
  Serial.println("║   AsthmaGuard Booting    ║");
  Serial.println("╚══════════════════════════╝\n");

  // ---- WIFI ----
  bool wifiOK = connectWiFi();

  // ---- TEST FLASK HEALTH ----
  if (wifiOK) {
    Serial.println("\n[Check] Testing Flask server...");
    Serial.printf("[Check] http://%s:%d/health\n", FLASK_IP, FLASK_PORT);
    HTTPClient http;
    http.begin(flaskURL("/health"));
    http.setTimeout(5000);
    int code = http.GET();
    if (code == 200) {
      Serial.println("[Check] ✓ Flask reachable!");
      Serial.println("[Check] Response: " + http.getString());
      http.end();
      loginToFlask();
    } else {
      Serial.printf("[Check] ✗ Flask not reachable (code: %d)\n", code);
      Serial.println("[Check] Run on Raspberry Pi terminal:");
      Serial.println("[Check]   python3 app.py");
      http.end();
    }
  }

  // ---- HARDWARE INIT ----
  Wire.begin(21, 22);
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(wifiOK    ? "WiFi : OK   " : "WiFi : FAIL ");
  lcd.setCursor(0, 1);
  lcd.print(flaskOnline ? "Flask: ON " : "Flask: OFF");

  pinMode(BUZZER_PIN,  OUTPUT);
  pinMode(LED_CONTROL, OUTPUT);
  digitalWrite(LED_CONTROL, HIGH);
  dht.begin();

  if (!pox.begin()) {
    Serial.println("\n[MAX30100] ✗ FAILED");
    Serial.println("[MAX30100] Check wiring SDA→21 SCL→22 VCC→3.3V GND→GND");
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print("MAX30100 FAIL");
    lcd.setCursor(0, 1); lcd.print("Check wiring");
    while (1);
  }
  pox.setIRLedCurrent(MAX30100_LED_CURR_50MA);
  Serial.println("[MAX30100] ✓ OK");

  // ---- CREATE TASKS ----
  xTaskCreatePinnedToCore(TaskMAX30100, "MAX30100", 2048, NULL, 3, NULL, 1);
  xTaskCreatePinnedToCore(TaskSensors,  "Sensors",  4096, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(TaskLCD,      "LCD",      2048, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(TaskAlert,    "Alert",    2048, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(TaskSerial,   "Serial",   2048, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(TaskFlask,    "Flask",    8192, NULL, 1, NULL, 0);

  Serial.println("[Setup] ✓ All tasks started");
  Serial.println("══════════════════════════════\n");
}

void loop() {}
