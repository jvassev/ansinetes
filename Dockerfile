FROM centos:7

VOLUME /tmp/.control

ENTRYPOINT ["/start.sh"]

RUN ln -s /ansinetes/ansible /etc/ansible || true

RUN curl -s -L -o /usr/bin/cfssl https://pkg.cfssl.org/R1.1/cfssl_linux-amd64 && \
    curl -s -L -o /usr/bin/cfssljson https://pkg.cfssl.org/R1.1/cfssljson_linux-amd64 && \
    chmod +x      /usr/bin/{cfssl,cfssljson}

RUN yum -y install python-setuptools gcc openssl-devel python-devel openssh python-crypto && \
	easy_install pip

RUN pip install ansible==2.1.1.0 && \
    pip install setuptools -U

COPY _defaults /_defaults

COPY start.sh /