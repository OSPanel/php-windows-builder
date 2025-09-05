Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bukka/php-crypto/4516e22160a32ea09b2e547ceebd9a009fc6b597/crypto_cipher.c" -OutFile "crypto_cipher.c"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bukka/php-crypto/4516e22160a32ea09b2e547ceebd9a009fc6b597/crypto_hash.c" -OutFile "crypto_hash.c"
mkdir phpc -Force | Out-Null; Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bukka/phpc/master/phpc.h" -OutFile "phpc\phpc.h"
