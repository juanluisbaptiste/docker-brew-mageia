FROM mageia:8
LABEL maintainer="Juan Luis Baptiste <juancho@mageia.org>"
ENV UID=1000
ENV HUB_VERSION=2.14.2

RUN dnf upgrade -y && \
     dnf install -y git sudo wget qemu-user-static xz && \
    echo "%wheel ALL=(ALL)  NOPASSWD:ALL" > /etc/sudoers.d/01wheel && \
    chmod 440 /etc/sudoers.d/01wheel && \
    useradd -u ${UID} -d /code -G wheel -M mageia
RUN wget https://github.com/github/hub/releases/download/v${HUB_VERSION}/hub-linux-amd64-${HUB_VERSION}.tgz && \
    pwd && \
    tar zxvf hub-linux-amd64-${HUB_VERSION}.tgz && \
    mv hub-linux-amd64-${HUB_VERSION}/bin/hub /usr/local/bin && \
    rm -fr hub-linux-*
USER mageia
VOLUME ["/code"]
CMD ["/bin/bash"]
