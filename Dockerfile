# JIRA_VERSION=9.17.4时使用
# FROM docker.1panel.dev/openjdk:8-alpine

# JIRA_VERSION=10.1.2时使用
FROM docker.1panel.dev/openjdk:17-alpine

# Configuration variables.
ENV JIRA_HOME=/var/atlassian/jira
ENV JIRA_INSTALL=/opt/atlassian/jira
#ENV JIRA_VERSION=9.17.4
ENV JIRA_VERSION=10.1.2

# 设置APK下载地址镜像
ENV APK_REPO=https://mirrors.ustc.edu.cn/alpine/v3.14

# 官方下载地址
#ENV JIRA_DOWNLOAD_HOST=https://www.atlassian.com/software/jira/downloads/binary
#ENV MYSQL_DRIVER_DOWNLOAD_HOST=https://dev.mysql.com/get/Downloads/Connector-J
#ENV POSTGRESQL_DOWNLOAD_HOST=https://jdbc.postgresql.org/download

# 本地下载地址
ENV JIRA_DOWNLOAD_HOST=http://127.0.0.1
ENV MYSQL_DRIVER_DOWNLOAD_HOST=http://127.0.0.1
ENV POSTGRESQL_DOWNLOAD_HOST=http://127.0.0.1

# Install Atlassian JIRA and helper tools and setup initial home
# directory structure.
RUN set -x \
    && echo "${APK_REPO}/main" > /etc/apk/repositories \
    && echo "${APK_REPO}/community" >> /etc/apk/repositories \
    && cat /etc/apk/repositories  \
    && apk add --no-cache curl xmlstarlet bash ttf-dejavu libc6-compat \
    && mkdir -p                "${JIRA_HOME}" \
    && mkdir -p                "${JIRA_HOME}/caches/indexes" \
    && chmod -R 700            "${JIRA_HOME}" \
    && chown -R daemon:daemon  "${JIRA_HOME}" \
    && mkdir -p                "${JIRA_INSTALL}/conf/Catalina" \
    && curl -Ls                "${JIRA_DOWNLOAD_HOST}/atlassian-jira-software-${JIRA_VERSION}.tar.gz" | tar -xz --directory "${JIRA_INSTALL}" --strip-components=1 --no-same-owner \
    && curl -Ls                "${MYSQL_DRIVER_DOWNLOAD_HOST}/mysql-connector-j-8.0.33.tar.gz" | tar -xz --directory "${JIRA_INSTALL}/lib" --strip-components=1 --no-same-owner "mysql-connector-j-8.0.33/mysql-connector-j-8.0.33.jar" \
    && rm -f                   "${JIRA_INSTALL}/lib/postgresql-9.1-903.jdbc4-atlassian-hosted.jar" \
    && curl -Ls                "${POSTGRESQL_DOWNLOAD_HOST}/postgresql-42.2.1.jar" -o "${JIRA_INSTALL}/lib/postgresql-42.2.1.jar" \
    && chmod -R 700            "${JIRA_INSTALL}/conf" \
    && chmod -R 700            "${JIRA_INSTALL}/logs" \
    && chmod -R 700            "${JIRA_INSTALL}/temp" \
    && chmod -R 700            "${JIRA_INSTALL}/work" \
    && chown -R daemon:daemon  "${JIRA_INSTALL}/conf" \
    && chown -R daemon:daemon  "${JIRA_INSTALL}/logs" \
    && chown -R daemon:daemon  "${JIRA_INSTALL}/temp" \
    && chown -R daemon:daemon  "${JIRA_INSTALL}/work" \
    && sed --in-place          "s/java version/openjdk version/g" "${JIRA_INSTALL}/bin/check-java.sh" \
    && echo -e                 "\njira.home=$JIRA_HOME" >> "${JIRA_INSTALL}/atlassian-jira/WEB-INF/classes/jira-application.properties" \
    && touch -d "@0"           "${JIRA_INSTALL}/conf/server.xml"

USER root

# 将代理破解包加入容器
COPY "atlassian-agent.jar" /opt/atlassian/jira/

# 设置启动加载代理包
RUN echo 'export CATALINA_OPTS="-javaagent:/opt/atlassian/jira/atlassian-agent.jar ${CATALINA_OPTS}"' >> /opt/atlassian/jira/bin/setenv.sh

# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
USER daemon:daemon

# Expose default HTTP connector port.
EXPOSE 8080

# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME ["/var/atlassian/jira", "/opt/atlassian/jira/logs"]

# Set the default working directory as the installation directory.
WORKDIR /var/atlassian/jira

COPY "docker-entrypoint.sh" "/"
ENTRYPOINT ["/docker-entrypoint.sh"]

# Run Atlassian JIRA as a foreground process by default.
CMD ["/opt/atlassian/jira/bin/start-jira.sh", "-fg"]
