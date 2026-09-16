"""Minimal App Store Connect API client. Usage: from asc import get, post, patch"""
import json, time, os, urllib.request, urllib.error
import jwt
KEY_ID = "77WKTNQ9N4"; ISS = "3648a1a5-87ed-4d94-8be7-b7bb00035686"
APP_ID = "6789274126"
VERSION_ID = "22813e42-ec73-4660-b25d-8ada1a5e5e31"
APP_INFO_ID = "25ef8406-8ee7-41d6-8661-7f694b7ac397"
_priv = open(os.path.expanduser("~/.appstoreconnect/private_keys/AuthKey_77WKTNQ9N4.p8")).read()
def _tok():
    return jwt.encode({"iss": ISS, "exp": int(time.time()) + 900, "aud": "appstoreconnect-v1"},
                      _priv, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})
def _req(method, path, body=None):
    url = path if path.startswith("http") else "https://api.appstoreconnect.apple.com/v1/" + path
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method,
        headers={"Authorization": "Bearer " + _tok(), "Content-Type": "application/json"})
    try:
        raw = urllib.request.urlopen(r).read()
        return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{e.code} {method} {path}: {e.read().decode()[:800]}")
def get(p): return _req("GET", p)
def post(p, b): return _req("POST", p, b)
def patch(p, b): return _req("PATCH", p, b)
