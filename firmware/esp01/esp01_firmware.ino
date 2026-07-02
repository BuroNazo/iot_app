/*
 * ESP-01 Firmware — Multi-User Firebase Sürüm v2
 * ================================================
 * - MAC adresi = Cihaz ID
 * - Firebase path: /users/{uid}/devices/{mac}
 * - EEPROM: WiFi + cihaz adı + Firebase UID
 * - 5 saniyede bir Firebase polling
 * - Provision sırasında Flutter'dan UID alır
 *
 * DEĞİŞİKLİK (2026-07-03): firebaseRegisterDevice() artık HTTP PATCH
 * kullanıyor (önceden PUT idi). PUT, Firebase RTDB'de o path'teki TÜM
 * veriyi siler ve sadece gönderilen alanlarla değiştirir — bu da cihaz
 * her açılışta/yeniden bağlandığında kullanıcının Flutter uygulamasında
 * oluşturduğu zamanlamaları (/schedules alt-node'u) sessizce siliyordu.
 * PATCH sadece belirtilen alanları günceller, kardeş node'lara dokunmaz.
 */

#include <ESP8266mDNS.h>
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClientSecureBearSSL.h>
#include <ArduinoJson.h>
#include <EEPROM.h>

// ── Pin Tanımları ──────────────────────────────────────────
#define RELAY_PIN       0
#define RELAY_ON        LOW
#define RELAY_OFF       HIGH

// ── AP Ayarları ────────────────────────────────────────────
#define AP_SSID         "OZDSOFT_ESPSetup"
#define AP_PASSWORD     ""
#define CONNECT_TIMEOUT 10000

// ── EEPROM ─────────────────────────────────────────────────
#define EEPROM_SIZE     160
#define SSID_ADDR       0
#define PASS_ADDR       32
#define NAME_ADDR       96
#define UID_ADDR        128

// ── Firebase ───────────────────────────────────────────────
#define FIREBASE_HOST   "iot1-bdd00-default-rtdb.firebaseio.com"
#define POLL_INTERVAL   5000

// ── Global Değişkenler ─────────────────────────────────────
ESP8266WebServer server(80);
bool relayState    = false;
unsigned long lastPoll = 0;
String deviceId    = "";
String deviceName  = "ESP Cihaz";
String firebaseUid = "";

// ──────────────────────────────────────────────────────────
// YARDIMCI FONKSİYONLAR
// ──────────────────────────────────────────────────────────

String getDeviceId() {
  String mac = WiFi.macAddress();
  mac.replace(":", "");
  mac.toLowerCase();
  return mac;
}

String getFirebasePath() {
  return "/users/" + firebaseUid + "/devices/" + deviceId;
}

// ── EEPROM Yaz ─────────────────────────────────────────────
void saveCredentials(const String& ssid, const String& password,
                     const String& name, const String& uid) {
  EEPROM.begin(EEPROM_SIZE);
  for (int i = 0; i < EEPROM_SIZE; i++) EEPROM.write(i, 0);
  for (unsigned int i = 0; i < ssid.length() && i < 31; i++)
    EEPROM.write(SSID_ADDR + i, ssid[i]);
  for (unsigned int i = 0; i < password.length() && i < 63; i++)
    EEPROM.write(PASS_ADDR + i, password[i]);
  for (unsigned int i = 0; i < name.length() && i < 31; i++)
    EEPROM.write(NAME_ADDR + i, name[i]);
  for (unsigned int i = 0; i < uid.length() && i < 31; i++)
    EEPROM.write(UID_ADDR + i, uid[i]);
  EEPROM.commit();
  EEPROM.end();
  Serial.println("EEPROM kaydedildi.");
}

// ── EEPROM Oku ─────────────────────────────────────────────
String readEepromString(int addr, int maxLen) {
  String result = "";
  EEPROM.begin(EEPROM_SIZE);
  for (int i = 0; i < maxLen; i++) {
    char c = EEPROM.read(addr + i);
    if (c == 0) break;
    result += c;
  }
  EEPROM.end();
  return result;
}

// ──────────────────────────────────────────────────────────
// FIREBASE FONKSİYONLARI
// ──────────────────────────────────────────────────────────

BearSSL::WiFiClientSecure* createSecureClient() {
  BearSSL::WiFiClientSecure* client = new BearSSL::WiFiClientSecure();
  client->setInsecure();
  client->setBufferSizes(512, 512);
  return client;
}

// Cihazı Firebase'e kaydet (var olan veriyi korur — PATCH kullanır)
void firebaseRegisterDevice() {
  if (firebaseUid.isEmpty()) return;

  BearSSL::WiFiClientSecure* client = createSecureClient();
  HTTPClient http;
  String url = "https://" + String(FIREBASE_HOST) + getFirebasePath() + ".json";

  http.begin(*client, url);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(8000);

  String body = "{\"name\":\"" + deviceName +
                "\",\"command\":\"OFF\",\"state\":\"OFF\",\"lastSeen\":0}";
  int code = http.PATCH(body);
  Serial.println("Firebase kayit kodu: " + String(code));
  Serial.println("Firebase path: " + getFirebasePath());

  http.end();
  delete client;
}

// Firebase'den komut oku
String firebaseGetCommand() {
  if (firebaseUid.isEmpty()) return "";

  BearSSL::WiFiClientSecure* client = createSecureClient();
  HTTPClient http;
  String url = "https://" + String(FIREBASE_HOST) +
               getFirebasePath() + "/command.json";

  http.begin(*client, url);
  http.setTimeout(8000);
  int code = http.GET();

  String result = "";
  if (code == 200) {
    String payload = http.getString();
    payload.replace("\"", "");
    payload.trim();
    result = payload;
  }
  http.end();
  delete client;
  return result;
}

// Firebase'e durum yaz
void firebaseSetState(const String& state) {
  if (firebaseUid.isEmpty()) return;

  BearSSL::WiFiClientSecure* client = createSecureClient();
  HTTPClient http;
  String url = "https://" + String(FIREBASE_HOST) +
               getFirebasePath() + ".json";

  http.begin(*client, url);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(8000);

  String body = "{\"state\":\"" + state +
                "\",\"lastSeen\":" + String(millis()) + "}";
  http.PATCH(body);
  http.end();
  delete client;
}

// Her 5 saniyede Firebase'i kontrol et
void pollFirebase() {
  if (WiFi.status() != WL_CONNECTED) return;
  if (firebaseUid.isEmpty()) return;
  if (millis() - lastPoll < POLL_INTERVAL) return;
  lastPoll = millis();

  String command = firebaseGetCommand();
  if (command.isEmpty()) return;
  Serial.println("Firebase komut: " + command);

  if (command == "ON" && !relayState) {
    relayState = true;
    digitalWrite(RELAY_PIN, RELAY_ON);
    Serial.println("Role ACILDI");
    firebaseSetState("ON");

  } else if (command == "OFF" && relayState) {
    relayState = false;
    digitalWrite(RELAY_PIN, RELAY_OFF);
    Serial.println("Role KAPATILDI");
    firebaseSetState("OFF");

  } else if (command == "RESET") {
    Serial.println("RESET komutu alindi!");
    firebaseSetState("OFF");
    EEPROM.begin(EEPROM_SIZE);
    for (int i = 0; i < EEPROM_SIZE; i++) EEPROM.write(i, 0);
    EEPROM.commit();
    EEPROM.end();
    delay(500);
    ESP.restart();
  }
}

// ──────────────────────────────────────────────────────────
// WEB SERVER
// ──────────────────────────────────────────────────────────

void addCorsHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
}

bool connectToWifi(const String& ssid, const String& password) {
  Serial.printf("WiFi baglaniliyor: %s\n", ssid.c_str());
  WiFi.mode(WIFI_AP_STA);
  WiFi.begin(ssid.c_str(), password.c_str());

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED) {
    if (millis() - start > CONNECT_TIMEOUT) {
      Serial.println("Zaman asimi!");
      return false;
    }
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nBaglandi! IP: " + WiFi.localIP().toString());
  WiFi.mode(WIFI_STA);
  return true;
}

void handleRoot() {
  addCorsHeaders();
  String html = "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>ESP-01</title>";
  html += "<style>body{font-family:sans-serif;display:flex;justify-content:center;";
  html += "align-items:center;min-height:100vh;margin:0;background:#f0f2f5}";
  html += ".card{background:#fff;border-radius:16px;padding:32px;text-align:center;width:300px}";
  html += ".btn{display:block;width:100%;padding:14px;border:none;border-radius:10px;";
  html += "font-size:16px;cursor:pointer;margin:8px 0}";
  html += ".on{background:#28a745;color:#fff}.off{background:#dc3545;color:#fff}</style></head>";
  html += "<body><div class='card'><h2>" + deviceName + "</h2>";
  html += "<p style='color:#888;font-size:12px'>ID: " + deviceId + "</p>";
  html += relayState
    ? "<p style='color:green;font-weight:bold'>ACIK</p>"
    : "<p style='color:red;font-weight:bold'>KAPALI</p>";
  html += "<button class='btn on' onclick=\"fetch('/on').then(()=>location.reload())\">AC</button>";
  html += "<button class='btn off' onclick=\"fetch('/off').then(()=>location.reload())\">KAPAT</button>";
  html += "</div></body></html>";
  server.send(200, "text/html; charset=utf-8", html);
}

void handleWifi() {
  addCorsHeaders();
  if (server.method() == HTTP_OPTIONS) { server.send(204); return; }
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"error\":\"body yok\"}");
    return;
  }

  StaticJsonDocument<300> doc;
  if (deserializeJson(doc, server.arg("plain"))) {
    server.send(400, "application/json", "{\"error\":\"json hatasi\"}");
    return;
  }

  const char* ssid     = doc["ssid"];
  const char* password = doc["password"] | "";
  const char* name     = doc["name"] | "ESP Cihaz";
  const char* uid      = doc["uid"] | "";

  if (!ssid || strlen(ssid) == 0) {
    server.send(400, "application/json", "{\"error\":\"ssid bos\"}");
    return;
  }

  deviceName  = String(name);
  firebaseUid = String(uid);

  // Hemen yanıt ver
  server.send(200, "application/json",
    "{\"status\":\"connecting\",\"id\":\"" + deviceId + "\"}");
  delay(200);

  bool connected = connectToWifi(String(ssid), String(password));
  if (connected) {
    saveCredentials(String(ssid), String(password), deviceName, firebaseUid);
    firebaseRegisterDevice();
  } else {
    WiFi.mode(WIFI_AP);
    WiFi.softAP(AP_SSID, AP_PASSWORD);
    Serial.println("Baglanamadi, AP moduna donuldu.");
  }
}

void handleOn() {
  addCorsHeaders();
  relayState = true;
  digitalWrite(RELAY_PIN, RELAY_ON);
  Serial.println("Role ACILDI");
  firebaseSetState("ON");
  server.send(200, "application/json", "{\"relay\":\"ON\"}");
}

void handleOff() {
  addCorsHeaders();
  relayState = false;
  digitalWrite(RELAY_PIN, RELAY_OFF);
  Serial.println("Role KAPATILDI");
  firebaseSetState("OFF");
  server.send(200, "application/json", "{\"relay\":\"OFF\"}");
}

void handleStatus() {
  addCorsHeaders();
  String json = "{\"relay\":\"";
  json += relayState ? "ON" : "OFF";
  json += "\",\"id\":\"" + deviceId;
  json += "\",\"name\":\"" + deviceName;
  json += "\",\"ip\":\"" + WiFi.localIP().toString() + "\"}";
  server.send(200, "application/json", json);
}

void handleReset() {
  addCorsHeaders();
  server.send(200, "application/json", "{\"status\":\"resetting\"}");
  delay(300);
  EEPROM.begin(EEPROM_SIZE);
  for (int i = 0; i < EEPROM_SIZE; i++) EEPROM.write(i, 0);
  EEPROM.commit();
  EEPROM.end();
  delay(200);
  ESP.restart();
}

void startServer() {
  if (MDNS.begin("esp01")) {
    MDNS.addService("http", "tcp", 80);
    Serial.println("mDNS: esp01.local");
  }
  server.on("/",       HTTP_GET,     handleRoot);
  server.on("/wifi",   HTTP_POST,    handleWifi);
  server.on("/wifi",   HTTP_OPTIONS, handleWifi);
  server.on("/on",     HTTP_GET,     handleOn);
  server.on("/off",    HTTP_GET,     handleOff);
  server.on("/status", HTTP_GET,     handleStatus);
  server.on("/reset",  HTTP_GET,     handleReset);
  server.begin();
  Serial.println("Sunucu basladi.");
}

// ──────────────────────────────────────────────────────────
// SETUP & LOOP
// ──────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  Serial.println("\n=== ESP-01 Multi-User v2 ===");

  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, RELAY_OFF);

  // MAC'ten cihaz ID'si al
  WiFi.mode(WIFI_STA);
  deviceId = getDeviceId();
  Serial.println("Cihaz ID: " + deviceId);

  // EEPROM'dan kayıtlı bilgileri oku
  String savedSsid = readEepromString(SSID_ADDR, 31);
  String savedPass = readEepromString(PASS_ADDR, 63);
  String savedName = readEepromString(NAME_ADDR, 31);
  String savedUid  = readEepromString(UID_ADDR,  31);

  if (!savedName.isEmpty()) deviceName  = savedName;
  if (!savedUid.isEmpty())  firebaseUid = savedUid;

  Serial.println("Kayitli UID: "  + firebaseUid);
  Serial.println("Cihaz Adi: "    + deviceName);

  if (savedSsid.length() > 0) {
    Serial.println("Kayitli WiFi: " + savedSsid);
    bool connected = connectToWifi(savedSsid, savedPass);
    if (connected) {
      startServer();
      // Firebase'e tekrar kayıt ol (IP güncellemesi için)
      if (!firebaseUid.isEmpty()) firebaseRegisterDevice();
      return;
    }
    Serial.println("Baglanti basarisiz, AP moduna geciliyor.");
  }

  // Kayıtlı WiFi yok veya bağlantı başarısız → AP modu
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASSWORD);
  Serial.println("AP modu: " + String(AP_SSID));
  Serial.println("Portal IP: " + WiFi.softAPIP().toString());
  startServer();
}

void loop() {
  MDNS.update();
  server.handleClient();
  pollFirebase();
}
