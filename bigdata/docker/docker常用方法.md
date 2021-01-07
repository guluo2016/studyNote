#### 1 docker的导入导出功能

---

docker的导出命令有两个：

- docker save

  > Save one or more images to a tar archive (streamed to STDOUT by default)
  >
  > 使用该命令可以将docker的镜像导出到外部，具体使用方法是：
  >
  > `docker save {镜像名} -o ./文件名`

- docker export

  > Export a container's filesystem as a tar archive
  >
  > docker export是将docker的容器导出到外部，具体使用方法是：
  >
  > `docker export {容器名} -o ./文件名`

docker的导入命令也有两个，分别对应于上面的导出

- docker load 

  > Load an image from a tar archive or STDIN
  >
  > docker load作用就是用于将一个已将镜像压缩文件导入到docker中，使用方法就是：
  >
  > `docker load -i ./{镜像文件}`

- docker import

  > Import the contents from a tarball to create a filesystem image
  >
  > docker import是将一个容器打包文件，导入到docker中，使用方法是：
  >
  > `docker import {容器文件} {自定义镜像及版本}`



<font color='red'>**需要注意的是通过`docker import`加载的docker镜像，在执行`docker run`的时候，需要带上`command`，否则会出错：**</font>

```shell
/usr/bin/docker-current: Error response from daemon: No command specified
```