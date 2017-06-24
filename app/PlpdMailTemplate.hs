module PlpdMailTemplate where

import System.IO(IO,putStrLn)

printMailTemplate :: IO ()
printMailTemplate = putStrLn "Sehr geehrter Herr Dr. Busse,\n\n\
\sehr geehrte Mitarbeiter der Kanzlei Busse,\n\n\n\
\wie schon im letzten Monat finden Sie unter folgendem Link alle\n\
\relevanten Dateien für unsere Buchhaltung für den vergangenen Monat:\n\n\
\https://finance.plapadoo.de/\n\n\
\Die Anmeldedaten sind Ihnen bereits bekannt.\n\n\n\
\Vielen Dank und mit freundlichen Grüßen\n\n\n\
\HIER NAME UNBEDINGT ERSETZEN SONST SEHR PEINLICH"
