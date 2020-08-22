docker rm -f szymonwarda
docker run --rm -it -p 4000:4000 -v //c/src/szymonwarda/:/site --name szymonwarda andredumas/github-pages serve --watch --force_polling