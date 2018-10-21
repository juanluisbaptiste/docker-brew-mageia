FROM mageia:6
MAINTAINER Juan Luis Baptiste <juan.baptiste@gmail.com>
ENV UID=1000

RUN dnf upgrade -y && \
     dnf install -y git sudo && \
    echo "%wheel ALL=(ALL)  NOPASSWD:ALL" > /etc/sudoers.d/01wheel && \
    chmod 440 /etc/sudoers.d/01wheel && \
    useradd -u ${UID} -d /code -G wheel -M mageia

USER mageia
VOLUME ["/code"]
CMD ["/bin/bash"]
