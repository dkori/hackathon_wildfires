FROM rstudio/plumber

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    lbzip2 \
    libfftw3-dev \
    libgdal-dev \
    libgeos-dev \
    libgsl0-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libhdf4-alt-dev \
    libhdf5-dev \
    libjq-dev \
    libpq-dev \
    libproj-dev \
    libprotobuf-dev \
    libnetcdf-dev \
    libsqlite3-dev \
    libssl-dev \
    libudunits2-dev \
    netcdf-bin \
    postgis \
    protobuf-compiler \
    sqlite3 \
    tk-dev \
    unixodbc-dev \
    wget\
    cabal-install \
    imagemagick \
    librsvg2-bin \
    librsvg2-common \
    zlib1g \
    pandoc 

RUN installGithub.r r-spatial/mapview \
&& rm -rf /tmp/downloaded_packages/

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
    && mkdir /tmp/phantomjs \
    && curl -L https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 \
           | tar -xj --strip-components=1 -C /tmp/phantomjs \
    && cd /tmp/phantomjs \
    && mv bin/phantomjs /usr/local/bin \
    && cd \
    && apt-get purge --auto-remove -y \
        curl \
    && apt-get clean \
    && rm -rf /tmp/* /var/lib/apt/lists
  
RUN R -e "install.packages('dplyr')"
Run R -e "install.packages('leaflet')"
Run R -e "install.packages('httr')"
Run R -e "install.packages('htmlwidgets')"
Run R -e "install.packages('tigris')"
Run R -e "install.packages('sf')"
Run R -e "install.packages('tidyr')"
Run R -e "install.packages('devtools')"
# add missing packages here
COPY . /app
CMD ["/app/api.R"]
