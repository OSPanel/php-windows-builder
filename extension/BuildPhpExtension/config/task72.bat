
call phpize 2>&1
call configure "--with-php-build=..\deps" OPTIONS "--enable-fd-setsize=8192" "--with-odbcver=0x0380" "--enable-com-dotnet=shared" "--without-analyzer" "--with-mp=disable" 2>&1
nmake /nologo 2>&1
exit %errorlevel%
