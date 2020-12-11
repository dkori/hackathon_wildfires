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
    unixodbc-dev

RUN R -e "install.packages('dplyr')"
Run R -e "install.packages('leaflet')"
Run R -e "install.packages('httr')"
Run R -e "install.packages('htmlwidgets')"
Run R -e "install.packages('tigris')"
Run R -e "install.packages('sf')"

# add missing packages here
COPY . /app
CMD ["/app/api.R"]
