#CMD healthcheck to check local http response on $PORT0
`test "$(curl -4 -w '%{http_code}' -s http://localhost:${PORT0}/|cut -f1 -d" ")" == 200`.
