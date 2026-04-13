@echo off
echo === Ouverture des ports Quantara ===
netsh advfirewall firewall add rule name="Quantara Web 4240" dir=in action=allow protocol=TCP localport=4240
netsh advfirewall firewall add rule name="Quantara API 4544" dir=in action=allow protocol=TCP localport=4544
echo.
echo === Verification ===
netsh advfirewall firewall show rule name="Quantara Web 4240"
netsh advfirewall firewall show rule name="Quantara API 4544"
echo.
echo Done.
pause
