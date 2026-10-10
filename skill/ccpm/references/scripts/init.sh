#!/bin/bash

echo "初期化中..."
echo ""
echo ""

echo " ██████╗ ██████╗██████╗ ███╗   ███╗"
echo "██╔════╝██╔════╝██╔══██╗████╗ ████║"
echo "██║     ██║     ██████╔╝██╔████╔██║"
echo "╚██████╗╚██████╗██║     ██║ ╚═╝ ██║"
echo " ╚═════╝ ╚═════╝╚═╝     ╚═╝     ╚═╝"

echo "┌─────────────────────────────────┐"
echo "│ Claude Code Project Management  │"
echo "│ by https://x.com/aroussi        │"
echo "└─────────────────────────────────┘"
echo "https://github.com/automazeio/ccpm"
echo ""
echo ""

echo "🚀 Claude Code PM システムの初期化"
echo "======================================"
echo ""

# 必須ツールの確認
echo "🔍 依存ツールを確認中..."

# gh CLI の確認
if command -v gh &> /dev/null; then
  echo "  ✅ GitHub CLI (gh) 導入済み"
else
  echo "  ❌ GitHub CLI (gh) 不在"
  echo ""
  echo "  gh を導入中..."
  if command -v brew &> /dev/null; then
    brew install gh
  elif command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install gh
  else
    echo "  GitHub CLI を手動で導入: https://cli.github.com/"
    exit 1
  fi
fi

# gh の認証状態の確認
echo ""
echo "🔐 GitHub 認証を確認中..."
if gh auth status &> /dev/null; then
  echo "  ✅ GitHub 認証済み"
else
  echo "  ⚠️ GitHub 未認証"
  echo "  実行中: gh auth login"
  gh auth login
fi

# gh-sub-issue 拡張の確認
echo ""
echo "📦 gh 拡張を確認中..."
if gh extension list | grep -q "yahsan2/gh-sub-issue"; then
  echo "  ✅ gh-sub-issue 拡張導入済み"
else
  echo "  📥 gh-sub-issue 拡張を導入中..."
  gh extension install yahsan2/gh-sub-issue
fi

# ディレクトリ構成の作成
echo ""
echo "📁 ディレクトリ構成を作成中..."
mkdir -p .claude/prds
mkdir -p .claude/epics
mkdir -p .claude/rules
mkdir -p .claude/agents
mkdir -p .claude/scripts/pm
echo "  ✅ ディレクトリ作成完了"

# main リポジトリ内であればスクリプトを複製
if [ -d "scripts/pm" ] && [ ! "$(pwd)" = *"/.claude"* ]; then
  echo ""
  echo "📝 PM スクリプトを複製中..."
  cp -r scripts/pm/* .claude/scripts/pm/
  chmod +x .claude/scripts/pm/*.sh
  echo "  ✅ スクリプトの複製と実行権限付与完了"
fi

# git の確認
echo ""
echo "🔗 Git 設定を確認中..."
if git rev-parse --git-dir > /dev/null 2>&1; then
  echo "  ✅ Git リポジトリを検出"

  # remote の確認
  if git remote -v | grep -q origin; then
    remote_url=$(git remote get-url origin)
    echo "  ✅ remote 設定済み: $remote_url"
    
    # remote が CCPM テンプレートリポジトリか確認
    if [[ "$remote_url" == *"automazeio/ccpm"* ]] || [[ "$remote_url" == *"automazeio/ccpm.git"* ]]; then
      echo ""
      echo "  ⚠️ 警告: remote origin が CCPM テンプレートリポジトリを指定"
      echo "  このままでは作成する Issue が自プロジェクトではなくテンプレートリポジトリへ登録。"
      echo ""
      echo "  修正手順:"
      echo "  1. リポジトリを fork、または GitHub 上に独自リポジトリを作成"
      echo "  2. remote を更新:"
      echo "     git remote set-url origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
      echo ""
    else
      # GitHub リポジトリであれば GitHub ラベルを作成
      if gh repo view &> /dev/null; then
        echo ""
        echo "🏷️ GitHub ラベルを作成中..."
        
        # エラー処理を強化した基本ラベルの作成
        epic_created=false
        task_created=false
        
        if gh label create "epic" --color "0E8A16" --description "Epic issue containing multiple related tasks" --force 2>/dev/null; then
          epic_created=true
        elif gh label list 2>/dev/null | grep -q "^epic"; then
          epic_created=true  # ラベル既存
        fi
        
        if gh label create "task" --color "1D76DB" --description "Individual task within an epic" --force 2>/dev/null; then
          task_created=true
        elif gh label list 2>/dev/null | grep -q "^task"; then
          task_created=true  # ラベル既存
        fi
        
        # 結果の報告
        if $epic_created && $task_created; then
          echo "  ✅ GitHub ラベル作成完了 (epic, task)"
        elif $epic_created || $task_created; then
          echo "  ⚠️ GitHub ラベルを一部のみ作成 (epic: $epic_created, task: $task_created)"
        else
          echo "  ❌ GitHub ラベル作成失敗 (リポジトリ権限を確認)"
        fi
      else
        echo "  ℹ️ GitHub リポジトリではないため、ラベル作成を省略"
      fi
    fi
  else
    echo "  ⚠️ remote 未設定"
    echo "  追加: git remote add origin <url>"
  fi
else
  echo "  ⚠️ git リポジトリではない"
  echo "  初期化: git init"
fi

# CLAUDE.md が不在であれば作成
if [ ! -f "CLAUDE.md" ]; then
  echo ""
  echo "📄 CLAUDE.md を作成中..."
  cat > CLAUDE.md << 'EOF'
# CLAUDE.md

> Think carefully and implement the most concise solution that changes as little code as possible.

## Project-Specific Instructions

Add your project-specific instructions here.

## Testing

Always run tests before committing:
- `npm test` or equivalent for your stack

## Code Style

Follow existing patterns in the codebase.
EOF
  echo "  ✅ CLAUDE.md 作成完了"
fi

# 要約
echo ""
echo "✅ 初期化完了"
echo "=========================="
echo ""
echo "📊 システム状態:"
gh --version | head -1
echo "  拡張: $(gh extension list | wc -l) 件導入済み"
echo "  認証: $(gh auth status 2>&1 | grep -o 'Logged in to [^ ]*' || echo '未認証')"
echo ""
echo "🎯 次の手順:"
echo "  1. 最初の PRD の作成: /pm:prd-new <feature-name>"
echo "  2. ヘルプの表示: /pm:help"
echo "  3. 状況の確認: /pm:status"
echo ""
echo "📚 文書: README.md"

exit 0
