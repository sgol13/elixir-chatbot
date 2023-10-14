# ElixirChatbot

## Using EXLA with the GPU

This project uses the EXLA backend for Nx. While it has support for computing on GPU, it will not be able to do so without proper configuration. This section will explain how to get EXLA running on a CUDA capable GPU. For further reading (for example, running the app on other architectures, there seems to be an experimental support for ROCm among others), refer to the [EXLA documentation](https://github.com/elixir-nx/nx/tree/main/exla) and [XLA binaries documentation](https://github.com/elixir-nx/xla).

### Find out what CUDA version your GPU supports

You can find it out either with nVidia's GUI tools or with the `nvidia-smi` command.

### Download CUDA and cuDNN libraries

The official releases are available here: [CUDA](https://developer.nvidia.com/cuda-downloads), [cuDNN](https://developer.nvidia.com/cudnn). For many platforms, there are special considerations and configuration needed - refer to online documentation for there.

For platforms which are not oficially supported (such as Arch Linux or NixOS) there are community packages available.

### Configure XLA to use correct binaries

If prebuilt XLA bineries for the CUDA version your GPU supports is also available on [XLA](https://github.com/elixir-nx/xla), you need to export several environment variables. Before doing so, make sure there are no old versions of binaries:

```shell
mix deps.clean xla exla
```

Then, export these variables with correct values. Refer to the documentation to find out what values your platform needs.

```shell
export CUDA_HOME="/opt/cuda" # path to where the CUDA libraries have been installed to
export PATH="/opt/cuda/bin:$PATH" # possibly optional
export XLA_TARGET=cuda120 # depending on the CUDA version on your GPU
export ELIXIR_ERL_OPTIONS="+sssdio 128" # grant additional stack space for the XLA compiler
export TF_CUDA_VERSION="12.2" # possibly optional, couldn't get it to work without it, though. Depends on CUDA version
export XLA_FLAGS=--xla_gpu_cuda_data_dir=/opt/cuda #path to where CUDA libraries have been installed to
```

After restarting the shell or sourcing appropriate files to update the environment, download and build the libraries again:

```shell
mix deps.get
mix deps.compile
```

You can check whether it works by launhing the `ElixirChatbotCore` app in interactive mode:

```shell
iex -S mix
```

```iex
iex(1)> Nx.tensor([1, 2, 3])
#Nx.Tensor<
  s64[3]
  EXLA.Backend<cuda:0, 0.3902074192.828768286.3250>
  [1, 2, 3]
>
```
