FROM openjdk:8-jdk-slim-buster

#############
## Jenkins ##
#############
ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG jenkins_user_home=/home/${user}

ENV JENKINS_USER_HOME=${jenkins_user_home} \
  LANG=C.UTF-8 \
  JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk \
  PATH=${PATH}:/usr/local/bin:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin \
  DOCKER_IMAGE_CACHE_DIR=/docker-cache \
  AUTOCONFIGURE_DOCKER_STORAGE=true

############
## Docker ##
############
ARG DOCKER_CHANNEL=stable
ARG DOCKER_VERSION=18.09.9

############
## Debian ##
############
# https://docs.docker.com/engine/install/debian/ 
RUN apt-get update && apt-get install -y --no-install-recommends \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg2 \
  software-properties-common \
  git

RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -

RUN add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   ${DOCKER_CHANNEL}"

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  docker-ce \
  docker-ce-cli \
  containerd.io && \
  docker -v && \
  dockerd -v

# https://github.com/moby/libnetwork/pull/2285
RUN echo "1" | update-alternatives --config iptables

#################
## DIND Script ##
#################
ARG DIND_COMMIT=52379fa76dee07ca038624d639d9e14f4fb719ff
#ENV DOCKER_EXTRA_OPTS '--storage-driver=overlay'
RUN curl -fL -o /usr/local/bin/dind "https://raw.githubusercontent.com/moby/moby/${DIND_COMMIT}/hack/dind" && \
	chmod +x /usr/local/bin/dind

# Set up default user for jenkins
RUN addgroup --gid ${gid} ${group} \
  && useradd --home-dir "${jenkins_user_home}" --create-home --uid "${uid}" -g "${group}" --shell /bin/bash ${user} \
  && echo "${user}:${user}" | chpasswd

# Adding the default user to groups used by Docker engine
RUN addgroup ${user} docker

################
## Entrypoint ##
################
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME /var/lib/docker
EXPOSE 2375

# Those folders should not be on the Docker "layers"
VOLUME ${jenkins_user_home} /docker-cache /tmp

# Default working directory
WORKDIR ${jenkins_user_home}

# Define the "default" entrypoint command executed on the container as PID 1
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

