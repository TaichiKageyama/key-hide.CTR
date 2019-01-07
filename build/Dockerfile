FROM debian:stable-slim
LABEL maintainer="32001477+TaichiKageyama@users.noreply.github.com"
RUN set -ex;                                                              \
    apt-get -qq update;                                                   \
    DEBIAN_FRONTEND=noninteractive apt-get -qq                            \
        -o Dpkg::Options::="--force-confdef"                              \
        -o Dpkg::Options::="--force-confold" install -y                   \
        gnupg steghide paperkey zbar-tools qrencode imagemagick           \
	graphicsmagick;       						  \
    apt-get -qq autoclean -y;                                             \
    apt-get -qq clean -y;                                                 \
    rm -rf /var/lib/apt/lists/*;
