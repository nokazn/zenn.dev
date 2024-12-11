---
title: "Nixでプロジェクトの環境構築をする"
emoji: "💫"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["nix", "direnv", "treefmt"]
published: false
---

## はじめに

この記事は、[Wano Group Advent Calendar 2024](https://qiita.com/advent-calendar/2024/wano-group)の11日目の記事です。

### Nixとは

Nixを簡潔に説明するのは難しいですが、以下のようないくつかの側面を持っています。

- 再現性の高いビルドシステムとしてのNix
- 上記のビルドシステム上でビルドしたパッケージを管理するパッケージマネージャとしてのNix
- ビルド設定を宣言的に記述するための独自DSLとしてのNix言語
- Nix言語で設定を記述し、Nixパッケージマネージャでパッケージ管理を行うLinuxディストリビューションとしてのNixOS

Nixとは何なのかについての詳細を知るには以下のBookがおすすめです。

https://zenn.dev/asa1984/books/nix-introduction

本稿では、パッケージマネージャーとしてのNixを使用して1プロジェクトの開発環境を用意する流れの一例を説明したいと思います。

## Nixを導入する

以下に従って、パッケージマネージャーとしてのNixをインストールします。

- [DeterminateSystems/nix-installerを用いたインストール手順](https://github.com/DeterminateSystems/nix-installer?tab=readme-ov-file#install-nix)
  - 後述するNix Flakesがデフォルトで使えるようになっています
- [公式のインストール手順](https://nixos.org/download/)
  - Nix Flakesを有効にするには`~/.config/nix/nix.conf`か`/etc/nix/nix.conf`に`experimental-features = nix-command flakes`の記述が必要です

`nix`コマンドが使用できるようになればインストール完了です。

```sh
$ nix --version
nix (Nix) 2.24.6
```

## Nix Flakeプロジェクトの作成

Nix FlakesとはNixで依存関係を宣言的に管理するための仕組みです。`flake.nix`というファイルで依存関係を宣言し、`flake.lock`というファイルで依存のバージョンを固定します。

以下のコマンドでNix Flakeプロジェクトを作成します。

```sh
# https://github.com/NixOS/templates で用意されているテンプレートの一覧
$ nix flake show templates

# 最小のflake.nixを生成
$ nix flake init --template 'templates#trivial'
```

ちなみに、Nix Flakesはまだ公式的には（インストール時の手順にもあったように）experimental featuresの扱いです。\
以前はNix Channelsという仕組みで管理されていて、それらを利用するのに古いコマンド体系である`nix-<サブコマンド名>`のようなコマンド（`nix-build`, `nix-shell`, `nix-env`等）で操作を行っていました。

Nix Flakesではコマンド体系も新しくなり、`nix <サブコマンド名>`のような形式になっています。
Nix関連の過去記事を読む際、それがどちらの管理方式前提で書かれたものなのか気をつけていただければと思います。

参考）[Flakes - NixOS Wiki](https://nixos.wiki/wiki/Flakes)

## `flake.nix`を記述する

`flake.nix`はNixで依存関係を管理するためのファイルです。種類としてはnpmの`package.json`や、cargoの`Cargo.toml`に近いものと言えるでしょう。

`flake.nix`では`input`と`output`という2つのattributeをメインに記載していきます。

- `inputs` - プロジェクトに必要な依存を定義
- `outputs` - ビルドして生成する出力を定義

ここでは以下のように`flake.nix`を記述します。

例）

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat.url = "github:edolstra/flake-compat";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nixfmt
            dprint
            yamlfmt
            shellcheck
            shfmt
            treefmt
            nodejs
            yarn-berry
          ];
      });
}
```

Nixのビルドシステムでは暗黙的な依存（環境ごとの共有リンクに依存している等）が発生しないよう保証されていて、`flake.nix`をチーム間で共有しておけば環境によって動作が異なるような事態（おま環）を避けることができます。

また、Nix Flakesでは、Git管理下にあるファイルを評価するようになっているため、一度`flake.nix`をコミットしておくとよいでしょう。

## 開発環境でコマンドを実行する

先ほど記述した、`outputs.devShells.<system>.default`のattributeは`nix develop`というコマンドに対応しています。\
このattributeで必要なパッケージを宣言すると、`nix develop`コマンド内でそのパッケージを利用することができます。

```sh
# Nix Flake環境に入る
$ nix develop

# Nix Flake環境の中でコマンドを実行
$ nix develop -c treefmt
```

`nix develop`を実行すると、`flake.lock`というバージョンを固定するためのファイルが生成されます。`flake.lock`で固定されたバージョンは`nix flake update`で更新することができます。

devShellでは、内から外は見えるが、外から内は見えないような状態になっており、元々の環境でパスが通っているコマンドはdevShell内でも実行できます。

また、devShellの設定で使用した`pkgs.mkShell`では、`shellHook`でdevShellに入った時に実行するコマンドを指定することもできます。

```diff
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nixfmt
            dprint
            yamlfmt
            shfmt
            shellcheck
            treefmt
            nodejs
            yarn-berry
          ];
+         shellHook = ''
+           yarn
+         '';
        };
```

npmパッケージのインストールなどが必要な場合はこれを活用するとよさそうです。

## direnvでプロジェクト配下に入った時にdevShellを起動する

環境変数の自動設定などに使用される[direnv](https://github.com/direnv/direnv)を、[nix-direnv](https://github.com/nix-community/nix-direnv)を用いて、devShellを起動するように設定することができます。

nix-direnvを使用するにはそれぞれの環境への[インストール](https://github.com/nix-community/nix-direnv)が別途必要です。

`.envrc`を作成し、

```profile
use flake
```

と記述し、プロジェクト配下で

```sh
$ direnv allow
```

を一度実行しておくと、Nix Flakeプロジェクト配下に入った時に自動でdevShellが起動し、必要な依存がすべて用意されます。

## treefmtでフォーマッターをまとめる

[treefmt](https://github.com/numtide/treefmt)という色々なフォーマッターをまとめるツールがあります。

以下のように`treefmt.toml`を作成し、

```toml
[formatter.nix]
command = "nixfmt"
includes = ["./**/*.nix"]

[formatter.dprint]
command = "dprint"
options = ["fmt"]
includes = ["./**/*.json", "./**/*.md", "./**/*.toml"]

[formatter.yaml]
command = "yamlfmt"
includes = ["./**/*.yaml", "./**/*.yml"]

[formatter.shellscript]
command = "shfmt"
includes = ["./**/*.sh"]
```

以下のようにコマンドを実行すると、それぞれのファイル形式ごとにまとめてフォーマットしてくれます。

```sh
$ nix develop -c treefmt
```

## GitHub ActionsでのCI/CD

CI/CD構築にあたってもNixはとても便利です。例えば、GitHub Actionsで特定の言語・ツールをインストールするのにsetup系のaction（`[actions/setup-node](https://github.com/actions/setup-node)`）などを利用することは多々ありますが、ここでNixを活用することもできます。\
Nixをインストールするactionには以下のようなものがあります。

- [cachix/install-nix-action](https://github.com/marketplace/actions/install-nix)
- [DeterminateSystems/nix-installer](https://github.com/determinateSystems/nix-installer)

また、以下のactionも入れておくと便利です。

- [DeterminateSystems/magic-nix-cache-action](https://github.com/DeterminateSystems/magic-nix-cache-action) - GitHub Actionsのビルトインキャッシュを利用してビルド時間を削減してくれる
- [DeterminateSystems/flake-checker-action](https://github.com/DeterminateSystems/flake-checker-action) - `flake.lock`を元にパッケージが古くなっていたりしないかチェックしてくれる

例）`.github/workflows/ci.yaml`等の設定例

```yaml
name: CI

on:
  push:
    branches:
      - main
  pull_request:
  workflow_dispatch:

jobs:
  static-check:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@27
      - uses: DeterminateSystems/magic-nix-cache-action@main
      - uses: DeterminateSystems/flake-checker-action@main
      - name: Check
        run: nix develop -c just check
```

### GitHub Actionsで`flake.lock`の定期的な更新を促す

Nix Flakeで管理しているパッケージの更新もGitHub Actionsで行うと便利です。

[DeterminateSystems/update-flake-lock](https://github.com/DeterminateSystems/update-flake-lock)というflake.lockの更新PRを自動で作成してくれるactionがあるので、これを定期的に実行させるようにしておくとよさそうです。

例）`.github/workflows/update.yaml`等の設定例

```yaml
name: update

on:
  schedule:
    # 毎月5日/25日の00:00に実行
    - cron: '0 0 5,25 * *'
  workflow_dispatch:

jobs:
  update-flake-lock:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - uses: DeterminateSystems/nix-installer-action@main
      - name: Generate branch date
        run: |
          echo "CURRENT_DATE=$(date +'%Y%m%d%H%M%S')" >> $GITHUB_ENV
      - uses: DeterminateSystems/update-flake-lock@main
        with:
          pr-title: "Update flake.lock"
          pr-labels: |
            dependencies
          pr-reviewers: ${{ github.actor }}
          branch: "deps/update-flake-lock-${{ env.CURRENT_DATE }}"
          commit-msg: "dpes: Update flake.lock"
          path-to-flake-dir: ./
```

## テンプレート化する

最初に登場した、`nix flake init`コマンドでは、テンプレートとしてGitHubやGitLab等のリポジトリ、任意のURLを指定することができます。

参考）[nix flake - Nix Reference Manual](https://nix.dev/manual/nix/2.24/command-ref/new-cli/nix3-flake#flake-references)

そのため、あるリポジトリにテンプレートを用意しておけば、`nix flake init --template github:<user>/<repository>#<directory>`でこれら全てを1コマンドで揃えることができます。

例えば、[nokazn/nix-starter](https://github.com/nokazn/nix-starter)というリポジトリの`rust`ディレクトリ配下に

```txt
|-- .envrc
|-- .gitattributes
|-- .github
|   └-- workflows
|       └-- ci.yaml
|-- .gitignore
|-- .vscode
|   └-- settings.json
|-- Cargo.lock
|-- Cargo.toml
|-- default.nix
|-- flake.nix
|-- justfile
|-- shell.nix
└-- src
    └-- main.rs
```

のようにファイルを用意しておくと、

```sh
$ nix flake init --template github:nokazn/nix-starter#rust
```

で全てのファイルがローカルにコピーされます。

## まとめ

Nixを調べたときに出てくる「純粋関数型」のようなワードを見ると重厚なイメージを持ってしまうかもしれません。ただ、必要に応じて少しだけ利用するみたいな手軽な使い方も可能なので、ニーズに応じて活用していただけるとよいかなと思いました。

みなさんも良きNixライフを！

## 最後に

WanoグループではWebエンジニアを募集しています。ご興味のある方は是非、 https://group.wano.co.jp/jobs/ からご応募ください！
