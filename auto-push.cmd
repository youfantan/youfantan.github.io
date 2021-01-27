git add .
set msg=
set /p msg=type commit message:
git commit -m "%msg%"
git pull origin master
git push origin master
pause