FROM rocker/geospatial:4.4.2
# https://github.com/rocker-org/rocker-versioned2/wiki/geospatial_69e6b17dd7e3

ENV NB_USER=rstudio
ENV NB_UID=1000
ENV CONDA_DIR=/srv/conda

# Set ENV for all programs...
ENV PATH=${CONDA_DIR}/bin:$PATH

# Pick up rocker's default TZ
ENV TZ=Etc/UTC

# And set ENV for R! It doesn't read from the environment...
RUN echo "TZ=${TZ}" >> /usr/local/lib/R/etc/Renviron.site
RUN echo "PATH=${PATH}" >> /usr/local/lib/R/etc/Renviron.site

# Add PATH to /etc/profile so it gets picked up by the terminal
RUN echo "PATH=${PATH}" >> /etc/profile
RUN echo "export PATH" >> /etc/profile

ENV HOME=/home/${NB_USER}

WORKDIR ${HOME}

# Install packages needed by notebook-as-pdf
# nodejs for installing notebook / jupyterhub from source
# libarchive-dev for https://github.com/berkeley-dsep-infra/datahub/issues/1997
RUN apt-get update > /dev/null && \
    apt-get install --yes \
            less \
            fonts-symbola \
            libx11-xcb1 \
            libxtst6 \
            libxrandr2 \
            libpangocairo-1.0-0 \
            libatk1.0-0 \
            libatk-bridge2.0-0 \
            libgtk-3-0 \
            libnss3 \
            libnspr4 \
            libxss1 \
            nodejs \
            npm \
            texlive-xetex \
            texlive-fonts-extra \
            texlive-latex-extra \
            texlive-fonts-recommended \
            texlive-lang-chinese \
            texlive-plain-generic \
            tini > /dev/null && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --chown=1000:1000 install-miniforge.bash /tmp/install-miniforge.bash
RUN /tmp/install-miniforge.bash
RUN rm -f /tmp/install-miniforge.bash

# needed for building on mac see DH-394
RUN chown -Rh ${NB_USER}:${NB_USER} ${HOME}

USER ${NB_USER}

COPY --chown=1000:1000 environment.yml /tmp/environment.yml
RUN mamba env update -p ${CONDA_DIR} -f /tmp/environment.yml && \
        mamba clean -afy
RUN rm -f /tmp/environment.yml

# DH-327, very similar to what was done for datahub in DH-164
ENV PLAYWRIGHT_BROWSERS_PATH ${CONDA_DIR}
RUN playwright install chromium

# Install IRKernel
RUN R --quiet -e "install.packages('IRkernel', quiet = TRUE)" && \
    R --quiet -e "IRkernel::installspec(prefix='${CONDA_DIR}')"

# Install extra R packages
RUN install2.r --error --skipinstalled \
    ## general interest 
    anytime    \
    Hmisc      \
    lmtest     \
    lubridate  \
    latex2exp  \
    MASS       \
    patchwork  \
    stargazer  \
    tidymodels \
    wooldridge \
    ## machine learning
    caret      \
    parsnip    \
    torch      \
    ## 241
    AER        \
    randomizr  \
    ## 271
    fable      \
    feasts     \
    fpp3       \
    gamlr      \
    plm        \
    lme4       \
    Quandl     \
    quantmod   \
    tseries    \
    tsibble    \
    vcd        \
    vars       \
    zoo

# Use simpler locking strategy
COPY file-locks /etc/rstudio/file-locks

# Doing a little cleanup
RUN rm -rf /tmp/downloaded_packages
RUN rm -rf ${HOME}/.cache

ENTRYPOINT ["tini", "--"]
