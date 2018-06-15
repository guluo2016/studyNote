## nginx转发请求遇到的问题

1 监听80端口，转发tomcat请求遇到404
我nginx监听的80端口
```
location /tomcat {
    proxy_pass http://localhost:8080;
}
```
解决办法就是在url后面加`/`就好了
```
location /tomcat {
    proxy_pass http://localhost:8080/;
}
```