FROM nvidia/cuda:12.3.1-devel-ubuntu22.04

ARG NOVNC_VERSION=1.2.0
ARG WEBSOCKIFY_VERSION=0.9.0

# Port
ARG LISTEN_PORT=8085
ARG VNC_PORT=5900
# Display size
ARG WIDHT=1024
ARG HEIGHT=768

ENV DISPLAY :0
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=C.UTF-8 \
    DISPLAY_WIDTH=${WIDHT} \
    DISPLAY_HEIGHT=${HEIGHT} \
    NOVNC_LISTEN_PORT=${LISTEN_PORT} \
    NOVNC_VNC_PORT=${VNC_PORT}

# Mute apt logs
ENV DEBIAN_FRONTEND noninteractive

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # utils
        wget curl gpg git apt-transport-https sudo \
        ca-certificates gnupg tzdata xauth uuid-dev \
        build-essential manpages-dev unzip dosfstools ssh \
        # SSH server
        openssh-server \
        # Install Zsh to use Oh My Zsh
        zsh \
        # Fcitx5-Mozc (Japanese IME)
        fcitx5-mozc \
        # Xfce4
        # https://github.com/coonrad/Debian-Xfce4-Minimal-Install
        libxfce4ui-utils thunar xfce4-appfinder xfce4-panel \
        xfce4-session xfce4-settings xfce4-terminal xfconf \
        xfdesktop4 xfwm4 xinit \
        # Remote Desktop
        dbus dbus-x11 alsa-utils pulseaudio \
        pulseaudio-utils mesa-utils x11-apps \
        xvfb x11vnc xdotool supervisor net-tools \
        dbus lxsession \
        # Websockify requires Python
        python3 python3-pip

# Create symbolic link to python3 for Websockify
RUN ln -s /usr/bin/python3 /usr/bin/python
# Websockify uses numpy to handle HyBi protocol
RUN pip3 install numpy

# Docker
# https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
RUN install -m 0755 -d /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/docker.asc https://download.docker.com/linux/ubuntu/gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
        https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin

# VS Code
# https://code.visualstudio.com/docs/setup/linux
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
        gpg --dearmor > packages.microsoft.gpg && \
    install -D -o root -g root -m 644 packages.microsoft.gpg \
        /etc/apt/keyrings/packages.microsoft.gpg && \
    sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] \
        https://packages.microsoft.com/repos/code stable main" > \
        /etc/apt/sources.list.d/vscode.list' && \
    rm -f packages.microsoft.gpg && \
    apt-get update && \
    apt-get install -y code

# Google Chrome
# https://zenn.dev/shimtom/articles/55fd2eb3d55c48
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | \
    gpg --dearmour -o /usr/share/keyrings/google-keyring.gpg && \
    sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-keyring.gpg] \
        http://dl.google.com/linux/chrome/deb/ stable main" >> \
        /etc/apt/sources.list.d/google-chrome.list' && \
    apt-get update && \
    apt-get install -y google-chrome-stable

# Oh My Zsh
# https://ohmyz.sh
RUN sh -c "$(wget https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -) \
    --unattended"

# Chrome Remote Desktop
RUN wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb && \
    apt-get install -y ./chrome-remote-desktop_current_amd64.deb && \
    rm -f chrome-remote-desktop_current_amd64.deb

# noVNC
RUN mkdir -p /usr/local/novnc && \
    curl -k -L -o /tmp/novnc.zip \
        https://github.com/novnc/noVNC/archive/v${NOVNC_VERSION}.zip && \
    unzip /tmp/novnc.zip -d /usr/local/novnc/ && \
    cp /usr/local/novnc/noVNC-${NOVNC_VERSION}/vnc.html \
        /usr/local/novnc/noVNC-${NOVNC_VERSION}/index.html && \
    curl -k -L -o /tmp/websockify.zip \
        https://github.com/novnc/websockify/archive/v${WEBSOCKIFY_VERSION}.zip && \
    unzip /tmp/websockify.zip -d /usr/local/novnc/ && \
    ln -sf /usr/local/novnc/websockify-${WEBSOCKIFY_VERSION} \
        /usr/local/novnc/noVNC-${NOVNC_VERSION}/utils/websockify && \
    rm -rf /tmp/novnc.zip /tmp/websockify.zip

ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY ./.inject_bashrc /root

COPY ./start.sh /

EXPOSE ${LISTEN_PORT}
EXPOSE ${VNC_PORT}

WORKDIR /root

CMD ["/start.sh"]
