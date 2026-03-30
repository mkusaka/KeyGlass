# KeyGlass 仕様書

## 概要

KeyGlass は、KeyCastr の中核となるキーボード可視化体験を Swift で再実装するための、ネイティブ macOS メニューバーアプリです。

このプロジェクトは、既存の Objective-C 実装をそのまま逐語的に移植することを目的としません。重要なユーザー体験を維持しつつ、保守しやすく拡張しやすい Swift ベースの構成へ作り直すことを目的とします。

## 目標

- KeyCastr の中核体験を置き換えられる、安定した Swift 実装を作る。
- 通常の Dock アプリではなく、軽量なメニューバーアプリとして動作させる。
- macOS の権限モデルに沿って、キーボードイベントを確実に取得する。
- 透明で邪魔になりにくいオーバーレイにキーストロークを表示する。
- modifier、特殊キー、非 US 配列を含めた表示の正しさを重視する。
- 最初はスコープを絞った v1 を先に完成させ、その後に機能互換を広げる。

## 最終プロダクトスコープ

KeyGlass の最終的な狙いは、KeyCastr のデフォルト利用体験を、古い実装モデルごと持ち込まずに、現代的な Swift 構成で実用的に置き換えることです。

### 入力取得スコープ

- listen-only の session event tap でキーボード入力を取得する。
- `keyDown` と `flagsChanged` を主要入力として扱う。
- 権限不足を明確に検出して表示する。
- tap が無効化または破棄された場合に健全に復帰できるようにする。
- secure input の制約は回避しようとせず、そのまま尊重する。

### 表示スコープ

- modifier 単体イベントを表示する。
- 組み合わせキーストロークを表示する。
- よく使う特殊キーを macOS 風 glyph で表示する。
- function key や拡張特殊キーも扱う。
- 透明オーバーレイと fade-out 表示を提供する。
- 連続入力でも読みやすさを保つため、queueing または coalescing を持つ。
- オーバーレイ位置、サイズ、不透明度、見た目を設定できる。
- Spaces をまたいだ通常利用で破綻しない表示挙動を持つ。

### 文字列化スコープ

- 現在のキーボードレイアウトに対して正しい表示へ変換する。
- 入力ソース変更を追跡し、それに応じて formatter 状態を更新する。
- 非 US 配列、特に JIS 系の挙動を実用レベルでサポートする。
- 最終表示で US 固定 key map に依存しない。
- 内部構造が異なっても、既存 KeyCastr ユーザーにとって自然な表示を目指す。

### アプリスコープ

- `LSUIElement` ベースのメニューバー常駐アプリとして動作する。
- メニューバーから capture の有効化と無効化を操作できる。
- オーバーレイ挙動と表示モードの設定 UI を提供する。
- 有効状態、オーバーレイ設定、表示モードなど主要設定を永続化する。
- coordinator、permission、capture、formatting、overlay、persistence の責務分離を維持する。

### 拡張機能スコープ

- KeyCastr で実用的だった表示モード、たとえば modifier-only、modified keys、all keys に相当するモードを持つ。
- キーボード体験が安定したあとで、基本的な mouse click 可視化を追加する。
- 日常利用の改善に効くなら、login at launch などのユーティリティ的 polish を追加する。

## リリース別スコープ

### V1 スコープ

- メニューバーアプリの殻。
- 権限確認と要求フロー。
- listen-only のキーボード event tap。
- on/off を切り替えられる capture 状態。
- 透明オーバーレイウィンドウ。
- 短い遅延後の自動 fade-out。
- modifier 単体表示。
- 組み合わせキーストローク表示。
- 矢印、escape、return、delete、tab、space などの基本特殊キー表示。
- mouse 可視化を含まない keyboard-only 実装。

### V1.1 スコープ

- オーバーレイ位置の永続化。
- サイズ、不透明度、表示時間などの基本的な見た目設定。
- 連続入力時の queueing または coalescing の改善。
- modifier-only、modified keys、all keys に相当する表示モード切り替え。
- menu bar 操作と、無効状態や権限不足状態のわかりやすい表示改善。

### V2 スコープ

- 入力ソース追跡。
- macOS のキーボードレイアウト API を使った layout-aware 変換。
- JIS を含む非 US 配列の対応強化。
- function key や、あまり使わない特殊キーまで含めた対応拡張。
- 基本的な mouse click 可視化。
- マルチディスプレイ時の表示ポリシー改善。

### 最終 parity ターゲット

- キーボード可視化について、KeyCastr のデフォルト利用モデルと機能的に同等であること。
- 古いアプリとのバイナリ互換ではなく、デフォルトオーバーレイ体験として機能的に同等であること。
- よく使う capture mode について、ユーザー視点で同等に使えること。
- レイアウト依存のキー表示について、ユーザー視点で同等に信頼できること。
- 実用価値が高いと判断できるなら、基本 mouse 可視化も含めること。

## parity の定義

このプロジェクトでいう parity とは、デフォルトの組み込み visualizer ワークフローにおける、ユーザー視点の機能的同等性を指します。upstream のソース構造、plugin API、設定ファイル形式、歴史的な全機能まで 1 対 1 で一致させることは意味しません。

KeyGlass は、現代の macOS 上でプレゼンターが KeyCastr の代わりに日常利用し、同程度に正しく、読みやすく、邪魔になりにくい表示を得られる状態を成功ラインとします。

## v1 の非目標

- upstream KeyCastr との完全な機能一致。
- visualizer のプラグイン構造。
- マウスクリックやドラッグの可視化。
- 既存 KeyCastr 設定の import。
- 自動更新、分析基盤、クラウド同期など配布後の機能。
- 実用に不要な高度テーマ機能。

## 恒久的な非スコープ

- upstream の Objective-C 実装を逐語的に Swift へ移植すること。
- 旧 KeyCastr の visualizer plugin を読み込むこと。
- upstream の設定ファイルや bundle 構造との互換維持。
- 生のキーストローク履歴の保存や再生。
- secure input を迂回したり、保護対象のパスワード入力を露出させること。
- クラウド同期、分析基盤、アカウント制御などサービス依存機能。
- 一般的な automation や macro ツールへ拡張すること。

## 対象プラットフォーム

- ネイティブ macOS アプリケーション。
- `LSUIElement` を使うメニューバー常駐ユーティリティ。
- 初期実装の対象は macOS 13 以降。
- 実行時の中核は AppKit、CoreGraphics、ApplicationServices を使う。
- 設定画面や軽量 UI には SwiftUI を使ってよいが、イベント取得とオーバーレイ管理は AppKit 主導にする。

## プロダクト要件

### 中核動作

- アプリはメニューバーに常駐して起動する。
- メニューバー UI から有効化と無効化を切り替えられる。
- 必要な入力監視権限を確認し、必要に応じて要求できる。
- listen-only の session event tap で `keyDown` と `flagsChanged` を取得する。
- `Command`、`Shift`、`Option`、`Control` など modifier 単体入力を表示できる。
- `⌘K`、`⌥⇧2`、矢印キーのような組み合わせ入力を表示できる。
- オーバーレイは透明ウィンドウとして通常アプリの上に表示される。
- 表示は短い遅延のあと自動でフェードアウトする。

### プライバシーと安全性

- 生のキーストロークを永続保存しない。
- secure input の挙動を尊重し、保護された入力が取得または表示できないことを受け入れる。
- 権限不足時に取得中のふりをせず、明確に失敗状態を示す。

### 表示の正しさ

- modifier glyph は macOS の慣例に従う。
- 矢印、escape、return、delete、tab、space などの特殊キーを明示的に描画する。
- formatter は最終的に、現在のキーボード入力ソースを考慮した layout-aware な変換に対応する。
- US 固定の keycode 表や `charactersIgnoringModifiers` だけでは最終実装として不十分とみなす。

## アーキテクチャ

アプリは次の責務に分けて構成する。

- `AppCoordinator`
  アプリ全体のライフサイクル、status item、capture 状態、高レベルな制御を担当する。
- `PermissionManager`
  実行中の macOS バージョンに応じて、Input Monitoring または Accessibility 権限を確認し要求する。
- `EventTapService`
  キーボードイベント用の event tap を install、start、stop し、状態を監視する。
- `KeystrokeFormatter`
  取得したイベントを表示文字列へ変換し、modifier glyph、特殊キー記号、入力ソース対応の変換を担当する。
- `OverlayWindowController`
  borderless なオーバーレイウィンドウ、表示更新、アニメーション、位置制御を担当する。
- `SettingsStore`
  オーバーレイ位置、サイズ、不透明度、有効状態など、ユーザー設定の永続化を担当する。

## 実装原則

- まずキーボードのみの最小実装を成立させる。
- 権限制御とイベント取得を分離する。
- イベント取得と文字列化を分離する。
- 文字列化と描画を分離する。
- view 主導の巨大な実装より、責務の明確なサービス境界を優先する。
- 二次的な polish より、信頼性とデバッグ容易性を優先する。

## マイルストーン

### Milestone 1: 動く土台

- メニューバーアプリの殻を作る。
- 権限確認と要求フローを入れる。
- listen-only のキーボード event tap を入れる。
- 基本的な透明オーバーレイを表示する。
- end-to-end で取得と表示が繋がる最小表示を実装する。

### Milestone 2: MVP

- modifier 単体表示。
- 特殊キー記号のマッピング。
- fade のタイミングと queueing。
- オーバーレイ位置と基本設定の永続化。
- capture の有効化と無効化を行う status item 操作。

### Milestone 3: 表示の正しさ

- 現在の入力ソース追跡。
- macOS のキーボードレイアウト API を使った layout-aware 変換。
- JIS を含む非 US 配列への対応強化。
- KeyCastr に近い formatter 挙動への改善。

### Milestone 4: v1 以降の拡張

- マウスイベントの可視化。
- スタイル設定の追加。
- さらに踏み込んだ設定 UI。
- 必要であれば plugin 型 visualizer の再評価。

## テスト方針

- `xcodebuild` による build 検証。
- formatter と event-to-display 変換の unit test。
- 権限フローと失敗時挙動の手動確認。
- 複数キーボード配列での手動確認。
- Spaces、フルスクリーンアプリ、オーバーレイの重なり順の手動確認。

## 未確定事項

- 最低サポート macOS バージョンを 13 のままにするかどうか。
- v1 にどこまで設定 UI を含めるか。
- マウス可視化を最終 parity ターゲットに含めるか、それとも任意拡張に留めるか。
- プレゼン用途で最も自然なマルチディスプレイ表示ポリシーをどうするか。
- MVP 安定後の署名と配布方法をどうするか。
