# Release 版本汇总

根目录的 `versions.json` 由 `.github/workflows/sync-versions.yml` 自动生成，以 GitHub Releases 为数据来源。每次读取所有分页，汇总全部已发布的正式版本和预发布版本，排除草稿以及只有 Git Tag、没有 Release 的版本，按发布时间从新到旧排列。

## 自动同步

- 发布、编辑、删除、取消发布 Release，或切换正式/预发布状态时，通过 Release 事件同步；对应标签的提交中需要已包含此工作流。
- 每小时第 17、47 分钟（UTC）从默认分支兜底同步，补齐旧标签、附件变化等未触发 Release 工作流的变更。GitHub 定时任务可能延迟，不保证在半小时内完成。
- 向默认分支推送生成脚本、对应测试或工作流的改动时同步，首次推送即可补齐历史记录。
- 可在 **Actions → Sync release versions → Run workflow** 选择默认分支手动同步。

工作流始终把结果提交到仓库默认分支（当前为 `main`），不会修改版本标签。只提交 `versions.json`；内容未变化时不提交，下载次数等易变数据不写入索引。API 请求失败时保留旧文件并使工作流失败；推送遇到其他提交时，从最新默认分支重新生成后重试，不强制推送。

使用 GitHub 自动提供的 `GITHUB_TOKEN`，工作流已声明 `contents: write`，通常不需要配置额外令牌。若分支保护或组织策略禁止机器人直接提交，需要允许对应写入。

先把工作流推送到默认分支，再基于包含工作流的提交创建新版本标签并发布 Release。Release 事件使用标签对应提交中的工作流；即使默认分支已存在工作流，旧标签对应提交中没有它时，也无法触发同步。更新或删除旧 Release、或在发布后单独增删附件时，可等待定时兜底，或手动运行工作流立即同步。如果以后使用另一条 Actions 工作流通过 `GITHUB_TOKEN` 创建 Release，该事件不会再触发本工作流；如需立即同步，应在发布流程完成后显式触发本工作流的 `workflow_dispatch`，或直接调用生成脚本并提交结果。

以上事件和令牌行为见 [GitHub 工作流事件说明](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#release)和 [GITHUB_TOKEN 触发限制](https://docs.github.com/en/actions/concepts/security/github_token#when-github_token-triggers-workflow-runs)。

## 新建 Release 后仍未同步

先在 Actions 页面查看是否出现 `release` 触发的 **Sync release versions** 运行记录。没有记录时，应核对标签指向的提交，而不是只看 Release 页面中的目标分支。

删除 Release 不会自动删除同名 Git 标签。重新发布并选择已有标签时，仍然使用旧标签对应的提交；即使目标分支显示 `main`，已有标签也不会自动移动到 `main` 的最新提交。如果那个提交中没有同步工作流，新建 Release 依然无法触发任务，而且自动生成的源码归档仍然来自旧提交。

后续发布应从包含工作流的最新提交创建一个尚未使用的新版本标签。如果需要保留当前已有 Release，可以在 **Actions → Sync release versions → Run workflow** 选择 `main` 手动同步索引；此操作只更新索引，不改变 Release 的标签、源码或附件。不应为了触发索引同步而直接移动已经发布的标签。

自动生成的提交只更新 GitHub 上的默认分支；本地工作区需要拉取后才能看到。实际文件名为 `versions.json`（带 `s`）。

## 文件格式

```json
{
  "schema_version": 1,
  "repository": "XCzongzi/xcshop",
  "releases": [
    {
      "id": 123,
      "tag_name": "v0.1.0",
      "name": "xcshop 0.1.0",
      "published_at": "2026-11-05T00:00:00Z",
      "prerelease": false,
      "html_url": "https://github.com/XCzongzi/xcshop/releases/tag/v0.1.0",
      "body": "Release 中填写的 Markdown 更新说明",
      "assets": [
        {
          "name": "xcshop-win64.zip",
          "size": 123456,
          "content_type": "application/zip",
          "browser_download_url": "https://github.com/XCzongzi/xcshop/releases/download/v0.1.0/xcshop-win64.zip",
          "digest": null
        }
      ]
    }
  ]
}
```

此处为格式示例。`published_at` 使用 GitHub 返回的 UTC 时间；`body` 保留原始 Markdown；`assets` 只包含已经上传完成的附件，按名称排序，`size` 单位为字节。GitHub 提供附件摘要时，`digest` 为 `sha256:…`，否则为 `null`。没有已发布版本时，`releases` 为空数组。API 规则见 [GitHub Releases API](https://docs.github.com/en/rest/releases/releases#list-releases)。

文件推送到公开仓库后可从以下地址读取：

```text
https://raw.githubusercontent.com/XCzongzi/xcshop/main/versions.json
```

默认分支改名后，读取地址也需调整。如需通过项目域名读取，可参照[套件自动打包的 Worker 映射](套件自动打包.md#下载地址与-worker)，把所需路径映射到上述文件。

## 本地生成与验证

使用 Node.js 22 或更新版本，不需要安装 npm 依赖：

```powershell
node --test tests/test_sync_versions.cjs
node tools/sync_versions.cjs
```

可使用 `--repository XCzongzi/xcshop` 指定来源，使用 `--output out/versions.json` 指定输出。默认来源为环境变量 `GITHUB_REPOSITORY`，未设置时为本项目；默认输出始终为本项目根目录的 `versions.json`。公开仓库可匿名读取；如需认证，从环境变量 `GITHUB_TOKEN` 读取，不要把令牌写进脚本或提交到仓库。

使用依赖系统证书的代理时，Node.js 24 可用 `node --use-system-ca --use-env-proxy tools/sync_versions.cjs` 运行。
