FROM buildpack-deps:jessie

EXPOSE 8080

# skip installing gem documentation
RUN mkdir -p /usr/local/etc \
	&& { \
		echo 'install: --no-document'; \
		echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc


ENV \
    # DEPRECATED: Use above LABEL instead, because this will be removed in future versions.
    STI_SCRIPTS_URL=image:///usr/libexec/s2i \
    # Path to be used in other layers to place s2i scripts into
    STI_SCRIPTS_PATH=/usr/libexec/s2i \
    APP_ROOT=/opt/app-root \
    # The $HOME is not set by default, but some applications needs this variable
    HOME=/opt/app-root/src \
    PATH=/opt/app-root/src/bin:/opt/app-root/bin:$PATH \
    RUBYGEMS_VERSION=2.7.6 \ 
    BUNDLER_VERSION=1.16.1

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="Ruby 2.1" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,ruby,ruby21" \
      io.openshift.s2i.scripts-url="image:///usr/libexec/s2i" \
      maintainer="Joao Oliveira <jbaojunior@gmail.com>"

# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built
RUN set -ex \
	\
	&& buildDeps=' \
		bison \
		dpkg-dev \
		libgdbm-dev \
    ruby \
		ruby2.1 \
		ruby2.1-dev \
    nodejs \
    bundler \
    rake \
    graphicsmagick \
    poppler-utils \
    poppler-data \
    tesseract-ocr \
    pdftk \
    libreoffice \
	' \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends $buildDeps \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /root/.gem/

#       && gem install therubyracer \
#	&& gem update --system "$RUBYGEMS_VERSION" \
#	&& gem install bundler --version "$BUNDLER_VERSION" --force \

# install things globally, for great justice
# and don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle

ENV BUNDLE_PATH="$GEM_HOME" \
	BUNDLE_BIN="$GEM_HOME/bin" \
	BUNDLE_SILENCE_ROOT_WARNING=1 \
	BUNDLE_APP_CONFIG="$GEM_HOME"

ENV PATH $BUNDLE_BIN:$PATH


RUN mkdir -p ${HOME}/.pki/nssdb && \
  chown -R 1001:0 ${HOME}/.pki && \
  useradd -u 1001 -r -g 0 -d ${HOME} -s /sbin/nologin -c "Default Application User" default && \
  chown -R 1001:0 ${APP_ROOT}

# Copy the S2I scripts from the specific language image to $STI_SCRIPTS_PATH
COPY ./s2i/bin/ /usr/libexec/s2i

# Copy extra files to the image.
COPY ./root/ /

RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
	&& chmod 777 "$GEM_HOME" "$BUNDLE_BIN" \
        && chown -R 1001:1001 "$GEM_HOME" "$BUNDLE_BIN" \
        && chown -R 1001:0 ${APP_ROOT} ${HOME} && chmod -R ug+rwx ${APP_ROOT} ${HOME}
       
USER 1001

WORKDIR ${HOME}

# CMD [ "irb" ]
CMD ["/usr/libexec/s2i/usage"]
