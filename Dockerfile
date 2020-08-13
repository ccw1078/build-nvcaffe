FROM nvidia/cuda:10.2-cudnn7-devel-ubuntu18.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        git \
        wget \
        libatlas-base-dev \
        libboost-all-dev \
        libgflags-dev \
        libgoogle-glog-dev \
        libhdf5-serial-dev \
        libleveldb-dev \
        liblmdb-dev \
        libopencv-dev \
        libprotobuf-dev \
        libsnappy-dev \
        protobuf-compiler \
        python-dev \
        python-numpy \
        python-pip \
        python-setuptools \
        python-scipy \
        vim \
        net-tools \
        python2.7 \
        python3.8 \
        iputils-ping \
        python3-pip \
        openssh-server \
        zip \
        unzip \
        libturbojpeg \
        libturbojpeg-dev \
        libopenblas-dev \
        libnccl2=2.7.8-1+cuda10.2 \
        libnccl-dev=2.7.8-1+cuda10.2 \
        libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN wget https://imagelib-picture.oss-cn-shenzhen.aliyuncs.com/library/cmake-3.16.5.tar.gz && \
    tar -zxvf cmake-3.16.5.tar.gz && \
    cd cmake-3.16.5 && \
    ./bootstrap && \
    make -j "$(nproc)"  && \
    make install && \
    cd ..  && \
    rm -rf cmake-3.16.5 && \
    rm -rf cmake-3.16.5.tar.gz

ENV CAFFE_ROOT=/opt/caffe

WORKDIR $CAFFE_ROOT

RUN pip install --upgrade pip

RUN git clone -b caffe-0.15 --depth 1 https://github.com/NVIDIA/caffe .

RUN cd python && for req in $(cat requirements.txt) pydot; do pip install $req; done && cd .. && \
    pip install protobuf && \
    mkdir build && cd build

RUN cd $CAFFE_ROOT && \
    sed -i 's|set(Caffe_known_gpu_archs "20 21(20) 30 35 50")|set(Caffe_known_gpu_archs "30 35 37 50 52 60 61 70 75")|g' cmake/Cuda.cmake && \
    cd build && cmake \
    -DUSE_CUDNN=1 \
    -DUSE_NCCL=ON \
    .. && make -j "$(nproc)"

RUN echo "export CAFFE_ROOT=/opt/caffe" >> /etc/profile

#ENV CAFFE_DATA $CAFFE_ROOT/build/tools
RUN echo "export CAFFE_DATA=$CAFFE_ROOT/build/tools" >> /etc/profile

#ENV PYCAFFE_ROOT $CAFFE_ROOT/python
RUN echo "export PYCAFFE_ROOT=$CAFFE_ROOT/python" >> /etc/profile

#ENV PYTHONPATH $PYCAFFE_ROOT:$PYTHONPATH
RUN echo "export PYTHONPATH=$CAFFE_ROOT/python:\$PYTHONPATH" >> /etc/profile

#ENV PATH $CAFFE_ROOT/build/tools:$PYCAFFE_ROOT:$PATH
RUN echo "export PATH=/opt/caffe/build/tools:/opt/caffe/python:/usr/local/nvidia/bin:/usr/local/cuda/bin:\$PATH" >> /etc/profile

RUN echo "export LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64:\$LD_LIBRARY_PATH" >> /etc/profile

RUN echo "export LIBRARY_PATH=/usr/local/cuda/lib64/stubs:\$LIBRARY_PATH" >> /etc/profile

#configure ssh
RUN mkdir /var/run/sshd

RUN echo 'root:root' | chpasswd

RUN sed -ri 's/^#?PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config

RUN mkdir /root/.ssh

RUN echo "$CAFFE_ROOT/build/lib" >> /etc/ld.so.conf.d/caffe.conf && ldconfig

EXPOSE 22