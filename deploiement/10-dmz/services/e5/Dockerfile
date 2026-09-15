FROM vulhub/tomcat:8.5.19

RUN cd /usr/local/tomcat/conf \
    && LINE="$(awk '/<servlet-name>default<\/servlet-name>/{in_default=1} in_default && /<load-on-startup>1/{print NR; exit} in_default && /<\/servlet>/{exit 1}' web.xml)" \
    && test -n "$LINE" \
    && ADDON='<init-param><param-name>readonly</param-name><param-value>false</param-value></init-param>' \
    && sed -i "$LINE i $ADDON" web.xml

COPY content/webapps/ROOT/ /usr/local/tomcat/webapps/ROOT/
