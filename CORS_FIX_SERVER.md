# CORS Fix for Chrome/Web Login & Register

Login aur register Chrome par nahi chal rahe kyunki **CORS** ke wajah se browser API calls block kar raha hai.

**Error:** `Request header field content-type is not allowed by Access-Control-Allow-Headers`

## Problem

Server par CORS headers hain lekin **`Content-Type`** allowed headers mein nahi hai. Flutter login/register JSON bhejta hai with `Content-Type: application/json`, jo server block kar raha hai.

## Solution: Server par CORS headers add karein

Aapke **ludo.eventsystem.online** server par yeh headers add karni hongi:

### Option 1: PHP files mein (recommended)

Har API file ke **sabse upar** (<?php ke turant baad) yeh add karein:

```php
<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Max-Age: 86400');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}
// ... rest of your PHP code
```

### Option 2: Apache .htaccess

Agar Apache use kar rahe ho, `api/` folder mein `.htaccess` banao:

```apache
Header set Access-Control-Allow-Origin "*"
Header set Access-Control-Allow-Methods "GET, POST, OPTIONS"
Header set Access-Control-Allow-Headers "Content-Type, Authorization"
```

### Option 3: Nginx

Nginx config mein add karein:

```nginx
add_header 'Access-Control-Allow-Origin' '*' always;
add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization' always;

if ($request_method = 'OPTIONS') {
    return 204;
}
```

---

## Local testing workaround (temporary)

Server fix karne se pehle test karne ke liye Chrome ko disable-web-security ke saath chala sakte ho:

```bash
# Mac
open -na "Google Chrome" --args --disable-web-security --user-data-dir=/tmp/chrome_dev

# Then run: flutter run -d chrome
```

**Note:** Yeh sirf local testing ke liye hai, production ke liye CORS server par properly configure karein.
