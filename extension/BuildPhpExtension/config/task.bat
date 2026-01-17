
call phpize 2>&1
call configure "--with-php-build=..\deps" OPTIONS "--enable-native-intrinsics=sse2,ssse3,sse4.1,sse4.2" "--with-mp=disable" 2>&1
nmake /nologo 2>&1
exit %errorlevel%
