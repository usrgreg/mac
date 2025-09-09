echo "data:image/png;base64,"$(base64 $1)
zbarimg -q $1|qrencode -t ansiutf8
