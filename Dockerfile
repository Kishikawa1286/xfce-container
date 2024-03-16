FROM nvidia/cuda:12.3.2-base-ubuntu22.04

ARG NOVNC_VERSION=1.4.0
ARG WEBSOCKIFY_VERSION=0.11.0

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

USER root

RUN apt-get update && apt-get install -y sudo

ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN mkdir -p /home/admin
COPY ./start.sh /home/admin
RUN chmod +x /home/admin/start.sh

# Create a user
RUN useradd -m admin

# Give sudo permission to the user "admin"
RUN echo "admin ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
RUN chown -R admin:admin /home/admin
USER admin

WORKDIR /home/admin

RUN sudo apt-get update && \
    sudo DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        # utils
        curl wget gpg git apt-transport-https \
        ca-certificates gnupg tzdata xauth uuid-dev \
        build-essential manpages-dev unzip dosfstools ssh \
        # SSH server
        openssh-server \
        # Fcitx5-Mozc (Japanese IME)
        fcitx5-mozc mozc-utils-gui im-config fcitx5-config-qt \
        # Xfce4
        # https://github.com/coonrad/Debian-Xfce4-Minimal-Install
        xubuntu-desktop xfce4-goodies xfce4 \
        # Network manager
        network-manager-gnome \
        # Icon themes
        paper-icon-theme moka-icon-theme papirus-icon-theme \
        # Have QT apps match the default GTK theme
        qt5ct adwaita-qt \
        # Fonts
        fonts-noto-cjk fonts-ipafont \
        # Remote Desktop
        dbus dbus-x11 alsa-utils pulseaudio \
        pulseaudio-utils mesa-utils x11-apps \
        xvfb x11vnc xdotool supervisor net-tools \
        dbus lxsession \
        # Websockify requires Python
        python3 python3-pip

RUN fc-cache -fv

# Create symbolic link to python3 for Websockify
RUN sudo ln -s /usr/bin/python3 /usr/bin/python
# Websockify uses numpy to handle HyBi protocol
RUN pip3 install numpy

# Docker
# https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
RUN sudo install -m 0755 -d /etc/apt/keyrings && \
    sudo wget -O /etc/apt/keyrings/docker.asc \
        https://download.docker.com/linux/ubuntu/gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
        https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    sudo apt-get update && \
    sudo apt-get install -y \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin && \
    # https://docs.docker.com/engine/install/linux-postinstall/
    sudo usermod -aG docker admin

# VS Code
# https://code.visualstudio.com/docs/setup/linux
RUN sudo wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
        sudo gpg --dearmor > packages.microsoft.gpg && \
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg \
        /etc/apt/keyrings/packages.microsoft.gpg && \
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] \
        https://packages.microsoft.com/repos/code stable main" > \
        /etc/apt/sources.list.d/vscode.list' && \
    rm -f packages.microsoft.gpg && \
    sudo apt-get update && \
    sudo apt-get install -y code

# Google Chrome
# https://zenn.dev/shimtom/articles/55fd2eb3d55c48
RUN sudo wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | \
    sudo gpg --dearmour -o /usr/share/keyrings/google-keyring.gpg && \
    sudo sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-keyring.gpg] \
        http://dl.google.com/linux/chrome/deb/ stable main" >> \
        /etc/apt/sources.list.d/google-chrome.list' && \
    sudo apt-get update && \
    sudo apt-get install -y google-chrome-stable

# Chrome Remote Desktop
RUN sudo wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb && \
    sudo DEBIAN_FRONTEND=noninteractive \
        apt-get install -y ./chrome-remote-desktop_current_amd64.deb && \
    rm -f chrome-remote-desktop_current_amd64.deb

# noVNC
RUN sudo mkdir -p /usr/local/novnc && \
    sudo curl -k -L -o /tmp/novnc.zip \
        https://github.com/novnc/noVNC/archive/v${NOVNC_VERSION}.zip && \
    sudo unzip /tmp/novnc.zip -d /usr/local/novnc/ && \
    sudo cp /usr/local/novnc/noVNC-${NOVNC_VERSION}/vnc.html \
        /usr/local/novnc/noVNC-${NOVNC_VERSION}/index.html

# Websockify
RUN sudo curl -k -L -o /tmp/websockify.zip \
        https://github.com/novnc/websockify/archive/v${WEBSOCKIFY_VERSION}.zip && \
    sudo unzip /tmp/websockify.zip -d /usr/local/novnc/ && \
    sudo ln -sf /usr/local/novnc/websockify-${WEBSOCKIFY_VERSION} \
        /usr/local/novnc/noVNC-${NOVNC_VERSION}/utils/websockify && \
    sudo rm -rf /tmp/novnc.zip /tmp/websockify.zip

# Fcitx5 configuraion
RUN echo "\
export GTK_IM_MODULE=fcitx\n\
export QT_IM_MODULE=fcitx\n\
export XMODIFIERS=@im=fcitx" >> ~/.xprofile

EXPOSE ${LISTEN_PORT}
EXPOSE ${VNC_PORT}

CMD ["/home/admin/start.sh"]
