FROM jupyter/minimal-notebook:latest
LABEL Description="Binder Env for Watershed Workflow and ATS"

ARG env_name=watershed_workflow
ARG user=jovyan
ENV CONDA_BIN=mamba

# 切回 root 以确保权限充足，解决 pip 警告
USER root

# 初始化基础目录
RUN mkdir -p /home/${user}/environments /home/${user}/tmp /home/${user}/data /home/${user}/workdir \
    && mkdir -p /opt/conda/envs/${env_name}/src

# 将 GitHub 仓库中的环境配置文件拷贝至镜像内 (需确保仓库目录结构一致)
COPY environments/environment-Linux.yml /home/${user}/environments/
COPY environments/environment-TOOLS-Linux.yml /home/${user}/environments/
COPY requirements.txt /home/${user}/tmp/
COPY environments/exodus_py.patch /opt/conda/envs/${env_name}/src/
COPY docker/configure-seacas.sh /home/${user}/tmp/
COPY watershed_workflowrc /home/${user}/.watershed_workflowrc

# 利用 mamba 构建并注册 Conda 环境
RUN --mount=type=cache,uid=1000,gid=100,target=/opt/conda/pkgs \
    ${CONDA_BIN} env create -f /home/${user}/environments/environment-Linux.yml && \
    ${CONDA_BIN} env create -f /home/${user}/environments/environment-TOOLS-Linux.yml

RUN ${CONDA_BIN} run -n ${env_name} python -m ipykernel install \
        --name watershed_workflow --display-name "Python3 (watershed_workflow)"

RUN ${CONDA_BIN} run -n ${env_name} python -m pip install -r /home/${user}/tmp/requirements.txt

# 配置环境变量以编译 Seacas
ENV PATH="/opt/conda/envs/watershed_workflow_tools/bin:${PATH}"
ENV SEACAS_DIR="/opt/conda/envs/${env_name}"
ENV CONDA_PREFIX="/opt/conda/envs/${env_name}"

WORKDIR /opt/conda/envs/${env_name}/src
RUN git clone -b v2021-10-11 --depth=1 https://github.com/gsjaardema/seacas/ seacas \
    && cd seacas \
    && git apply ../exodus_py.patch

WORKDIR /home/${user}/tmp
RUN chmod +x configure-seacas.sh \
    && mkdir seacas-build \
    && cd seacas-build \
    && ${CONDA_BIN} run -n watershed_workflow_tools ../configure-seacas.sh \
    && make -j install

RUN cp /opt/conda/envs/${env_name}/lib/exodus3.py /opt/conda/envs/${env_name}/lib/python3.10/site-packages/

# 拷贝 Watershed Workflow 源码并安装
COPY . /home/${user}/watershed_workflow
WORKDIR /home/${user}/watershed_workflow
RUN ${CONDA_BIN} run -n watershed_workflow python -m pip install -e .

# 部署 Amanzi-ATS 及依赖组件
RUN mkdir -p /home/${user}/ats
WORKDIR /home/${user}/ats
RUN git clone --recursive --depth=1 https://github.com/amanzi/amanzi amanzi-ats
WORKDIR /home/${user}/ats/amanzi-ats/tools/amanzi_xml
RUN ${CONDA_BIN} run -n ${env_name} python -m pip install -e .

ENV AMANZI_SRC_DIR=/home/${user}/ats/amanzi-ats
ENV ATS_SRC_DIR=/home/${user}/ats/amanzi-ats/src/physics/ats
ENV PYTHONPATH=/home/${user}/ats/amanzi-ats/src/physics/ats/tools/utils

WORKDIR /home/${user}/ats/
RUN git clone --depth=1 https://github.com/ecoon/ats_input_spec ats_input_spec
WORKDIR /home/${user}/ats/ats_input_spec
RUN ${CONDA_BIN} run -n ${env_name} python -m pip install -e .

# 清理缓存并修复权限，Binder 强制要求使用非 root 用户启动
RUN rm -rf /home/${user}/tmp \
    && chown -R ${user}:100 /home/${user} \
    && chown -R ${user}:100 /opt/conda

USER ${user}
WORKDIR /home/${user}/workdir