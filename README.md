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
export XLA_FLAGS=--xla_gpu_cuda_data_dir=/opt/cuda # path to where CUDA libraries have been installed to
```

After restarting the shell or sourcing appropriate files to update the environment, download and build the libraries again:

```shell
$ mix deps.get
$ mix deps.compile
```

You can check whether it works by launhing the `ElixirChatbotCore` app in interactive mode:

```shell
$ iex -S mix
```

```iex
iex(1)> Nx.tensor([1, 2, 3])
#Nx.Tensor<
  s64[3]
  EXLA.Backend<cuda:0, 0.3902074192.828768286.3250>
  [1, 2, 3]
>
```

## Creating the documentation database

While the `ElixirChatbotCore` app does provide the functionality needed to create a database, a utility module `Tests.DocsFetcher` in the `tests` app is provided. It exports the `fetch_documentation` function, which streamlines documentation preprocessing and database creation.

To use the package, simply enter the interactive Elixir prompt and call the function with the database name and relevant options.

```shell
$ cd apps/tests
$ iex -S mix
```

```iex
iex(1)> Tests.DocsFetcher.fetch_documentation("db-1", headings_split: 1) # no preprocessing
iex(2)> Tests.DocsFetcher.fetch_documentation("db-2", headings_split: 2, prepend_parent_heading: true, max_token_count: 256) # split with respect to Markdown subheadings, prepend parent heading to fragments and limit fragment length to 256 words
iex(3)> Tests.DocsFetcher.fetch_documentation("db-3", headings_split: 1, allowed_modules: Application.spec(:elixir, :modules)) # fetch core Elixir docs only
```

The databases will be created in the `<project_root>/tmp` directory by default.

## Setup

### Installing all necessary dependencies

To run this project, install all necessary dependencies using `mix` and `npm`:

```shell
$ mix deps.get
$ cd apps/chat_web
$ npm install highlight.js --prefix assets
```

### Setting up OpenAI API Key

To use OpenAI models within our project, you have to create an OpenAI account and configure your OpenAI API Key. Step-by-step instructions can be found in [OpenAI Documentation](https://platform.openai.com/docs/quickstart/step-2-setup-your-api-key).

### Running the project

To run this project, simply proceed to `chat_web` app and use `mix`:

```shell
$ cd apps/chat_web
$ mix phx.server
```