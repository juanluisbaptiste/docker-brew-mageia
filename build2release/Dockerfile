FROM mageia:6
MAINTAINER Juan Luis Baptiste <juancho@mageia.org>
ENV UID=1000

RUN dnf upgrade -y && \
     dnf install -y git sudo wget && \
    echo "%wheel ALL=(ALL)  NOPASSWD:ALL" > /etc/sudoers.d/01wheel && \
    chmod 440 /etc/sudoers.d/01wheel && \
    useradd -u ${UID} -d /code -G wheel -M mageia
RUN wget https://github.com/github/hub/releases/download/v2.5.1/hub-linux-amd64-2.5.1.tgz && \
    pwd && \
    tar zxvf hub-linux-amd64-2.5.1.tgz && \
    mv hub-linux-amd64-2.5.1/bin/hub /usr/local/bin && \
    rm -fr hub-linux-*
USER mageia
VOLUME ["/code"]
CMD ["/bin/bash"]
