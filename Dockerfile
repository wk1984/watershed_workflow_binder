FROM pshuai/ats_workflow

# Binder 的标准运行用户通常是 jovyan，UID 为 1000
ARG NB_USER=jovyan
ARG NB_UID=1000
ENV USER ${NB_USER}
ENV NB_UID ${NB_UID}
ENV HOME /home/${NB_USER}

# 将 GitHub 仓库根目录下的所有文件拷贝到容器的工作目录中
# 必须使用 --chown 赋予当前用户权限，否则在 Jupyter 环境中编辑或运行脚本时会报 Permission Denied
COPY --chown=${NB_UID}:${NB_UID} . ${HOME}

# 设定默认工作路径
WORKDIR ${HOME}

# 切换回默认的非 root 用户，这是 MyBinder 成功启动服务的必要条件
USER ${USER}