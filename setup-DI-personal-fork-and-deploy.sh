#!/bin/bash
# setup-DI-personal-fork-and-deploy.sh
# Name: 'Setup designers.italia.it personal fork GitHub Pages Deploy'
# Description: 'Automatically configure your fork of designers.italia.it for GitHub Pages deployment' 
# Author: 'Fupete'
# Launch with: 'chmod +x setup-DI-personal-fork-and-deploy.sh' and then './setup-DI-personal-fork-and-deploy.sh'

USERNAME="$1"
REPO_NAME="${2:-designers.italia.it}"

if [ -z "$USERNAME" ]; then
    echo "Usage: $0 <username> [repo-name]"
    echo "Example: $0 fupete designers.italia.it"
    exit 1
fi

echo "Local setup for GitHub Pages deploy: $USERNAME/$REPO_NAME"

# Controlla che siamo in una repo designers.italia.it
if [ ! -f "gatsby-config.js" ] || [ ! -d "src/data" ]; then
    echo "ERROR: non sembra una repo designers.italia.it"
    echo "Esegui da dentro la cartella della repo clonata"
    exit 1
fi

# Backup files che stiamo per modificare
echo "Creating backups..."
cp gatsby-config.js gatsby-config.js.backup
cp package.json package.json.backup
[ -f ".github/workflows/deploy.yml" ] && cp .github/workflows/deploy.yml .github/workflows/deploy.yml.backup

echo "Configuring Gatsby..."
# pathPrefix
sed -i.tmp 's|pathPrefix: "/"|pathPrefix: "/'$REPO_NAME'"|g' gatsby-config.js

# siteUrl (both formats)
sed -i.tmp "s|siteUrl: \`https://designers.italia.it\`|siteUrl: \`https://$USERNAME.github.io/$REPO_NAME\`|g" gatsby-config.js
sed -i.tmp "s|siteUrl: \"https://designers.italia.it\"|siteUrl: \"https://$USERNAME.github.io/$REPO_NAME\"|g" gatsby-config.js

rm -f gatsby-config.js.tmp

# Comment out Matomo plugin
echo "Commenting out Matomo plugin..."
resolve_line=$(grep -n 'resolve: "gatsby-plugin-matomo"' gatsby-config.js | cut -d: -f1)
error_tracking_line=$(grep -n 'enableJSErrorTracking: true' gatsby-config.js | cut -d: -f1)

if [ -n "$resolve_line" ] && [ -n "$error_tracking_line" ]; then
    # Find the opening brace before resolve line
    start_line=""
    for ((i=resolve_line-3; i<=resolve_line; i++)); do
        if [ $i -gt 0 ]; then
            line_content=$(sed -n "${i}p" gatsby-config.js)
            if [[ "$line_content" =~ ^[[:space:]]*\{[[:space:]]*$ ]]; then
                start_line=$i
            fi
        fi
    done
    
    # Find the closing brace after error tracking line
    end_line=""
    max_lines=$(wc -l < gatsby-config.js)
    for ((i=error_tracking_line; i<=error_tracking_line+3 && i<=max_lines; i++)); do
        line_content=$(sed -n "${i}p" gatsby-config.js)
        if [[ "$line_content" =~ ^[[:space:]]*\},[[:space:]]*$ ]]; then
            end_line=$i+1
            break
        fi
    done
    
    if [ -n "$start_line" ] && [ -n "$end_line" ]; then
        echo "Commenting Matomo plugin lines $start_line to $end_line"
        sed -i.tmp "${start_line},${end_line}s|^|// |" gatsby-config.js
        rm -f gatsby-config.js.tmp
    else
        echo "Warning: Could not find complete Matomo plugin block boundaries"
    fi
else
    echo "Matomo plugin not found or already commented"
fi

# Validate syntax
if ! node -c gatsby-config.js 2>/dev/null; then
    echo "ERROR: gatsby-config.js syntax error"
    cp gatsby-config.js.backup gatsby-config.js
    exit 1
fi

echo "Configuring package.json..."
sed -i.tmp 's|"url": "git+https://github.com/italia/designers.italia.it.git"|"url": "git+https://github.com/'$USERNAME'/'$REPO_NAME'.git"|g' package.json
sed -i.tmp 's|"url": "https://github.com/italia/designers.italia.it/issues"|"url": "https://github.com/'$USERNAME'/'$REPO_NAME'/issues"|g' package.json
sed -i.tmp 's|"homepage": "https://designers.italia.it/"|"homepage": "https://'$USERNAME'.github.io/'$REPO_NAME'/"|g' package.json
sed -i.tmp "s|Deploy Bot <no-reply@teamdigitale.governo.it>|GitHub <$USERNAME@users.noreply.github.com>|g" package.json

rm -f package.json.tmp

echo "Updating workflows..."
if [ -f ".github/workflows/deploy.yml" ]; then
    sed -i.tmp '/npm run build$/,/^[[:space:]]*- name:/ {
        /env:/,/MATOMO_SITE_URL:/ d
    }' .github/workflows/deploy.yml    
    sed -i.tmp '/echo designers.italia.it > public\/CNAME/d' .github/workflows/deploy.yml
    sed -i.tmp "s|italia/designers.italia.it|$USERNAME/$REPO_NAME|g" .github/workflows/deploy.yml
    rm -f .github/workflows/deploy.yml.tmp
    echo "deploy workflow configured"
fi

if [ -f ".github/workflows/bsi-update.yml" ]; then
    sed -i.tmp "s|'4 10 \* \* \*'|'4 10 * * 1'|g" .github/workflows/bsi-update.yml
    sed -i.tmp "s|DEVELOPERS_ITALIA_DROID_GITHUB_TOKEN|GITHUB_TOKEN|g" .github/workflows/bsi-update.yml
    rm -f .github/workflows/bsi-update.yml.tmp
    echo "bsi-update workflow configured"
fi

echo "Updating YAML asset URLs..."
modified_count=0
find src/data/content -name "*.yml" -o -name "*.yaml" | while read file; do
    if [ -f "$file" ]; then
        # Backup del file
        cp "$file" "$file.backup"
        
        # Asset URLs with extensions
        sed -i.tmp "s|https://designers\.italia\.it/\([^\"]*\.\(jpg\|jpeg\|png\|gif\|svg\|webp\|pdf\|zip\|mp4\|mov\)\)|https://$USERNAME.github.io/$REPO_NAME/\1|g" "$file"
        
        # Specific asset fields
        sed -i.tmp "s|img: https://designers\.italia\.it/images/|img: https://$USERNAME.github.io/$REPO_NAME/images/|g" "$file"
        sed -i.tmp "s|image: https://designers\.italia\.it/images/|image: https://$USERNAME.github.io/$REPO_NAME/images/|g" "$file"
        sed -i.tmp "s|background: https://designers\.italia\.it/assets/|background: https://$USERNAME.github.io/$REPO_NAME/assets/|g" "$file"
        
        rm -f "$file.tmp"
        
        # Check if anything was changed
        if ! cmp -s "$file" "$file.backup"; then
            echo "Updated assets in: $file"
            modified_count=$((modified_count + 1))
        fi
        rm "$file.backup"
    fi
done

echo "Updating Bootstrap Italia template..."
if [ -f "static/examples/templates/base.html" ]; then
    cp static/examples/templates/base.html static/examples/templates/base.html.backup
    sed -i.tmp "s|__PUBLIC_PATH__ = \"/dist/fonts/\"|__PUBLIC_PATH__ = \"/$REPO_NAME/dist/fonts/\"|g" static/examples/templates/base.html
    rm -f static/examples/templates/base.html.tmp
    echo "BSI template updated"
    rm static/examples/templates/base.html.backup
fi

echo "Updating component SVG paths..."
if [ -f "src/components/icon/icon.js" ]; then
    cp src/components/icon/icon.js src/components/icon/icon.js.backup
    sed -i.tmp "s|\`/svg/\${icon}\`|\`/$REPO_NAME/svg/\${icon}\`|g" src/components/icon/icon.js
    rm -f src/components/icon/icon.js.tmp
    echo "Icon component paths updated"
    rm src/components/icon/icon.js.backup
fi

echo "Updating component view BSI example paths..."
if [ -f "src/components/component-view/component-view.js" ]; then
    cp src/components/component-view/component-view.js src/components/component-view/component-view.js.backup
    sed -i.tmp "s|\`/examples/\${source}/\${slugify(|\`/$REPO_NAME/examples/\${source}/\${slugify(|g" src/components/component-view/component-view.js
    rm -f src/components/component-view/component-view.js.tmp
    echo "Component view BSI example paths updated"
    rm src/components/component-view/component-view.js.backup
fi

echo "Updating font paths in SCSS..."
if [ -f "src/scss/fonts.scss" ]; then
    cp src/scss/fonts.scss src/scss/fonts.scss.backup
    sed -i.tmp "s|\$font-path: \"/fonts\"|\$font-path: \"/$REPO_NAME/fonts\"|g" src/scss/fonts.scss
    rm -f src/scss/fonts.scss.tmp
    echo "Font paths updated in SCSS"
    rm src/scss/fonts.scss.backup
fi

echo ""
echo "Setup completed successfully!"
echo ""
echo "Modified files:"
git status --porcelain | head -10
echo "..."
echo ""
echo "Next steps:"
echo "0. If new fork install dependencies: run npm i" 
echo "1. Test syntax: node -c gatsby-config.js"
echo "2. Check changes: git diff --name-only"
echo "3. Update BSI examples: npm run prepare-content"
echo "4. Test locally: npm run develop (SEO images errors 1st time and wrong fonts are ok)"
echo "5. Commit: git add . && git commit -m 'Configure GitHub Pages deploy'"
echo "6. Push: git push origin main"
echo "7. Prepare deploy: (a) Enable Github Pages Deploy from Actions (b) Create gh-pages branch (c) Launch 'Prepare Deploy' workflow"
echo "7. Deploy DI fork/mirror: go to GitHub Actions tab and run 'Deploy' workflow"
echo ""
echo "Site fork/mirror will be available at: https://$USERNAME.github.io/$REPO_NAME"
echo ""
echo "To undo changes: git restore ."
echo ""
echo "FUTURE UPDATES:"
echo "When italia/designers.italia.it gets new commits, to update your fork:"
echo "1. git remote add upstream https://github.com/italia/designers.italia.it.git (only first time)"
echo "2. git fetch upstream"
echo "3. git merge upstream/main (or rebase if preferred)"
echo "4. ./setup-DI-personal-fork-and-deploy.sh $USERNAME $REPO_NAME (re-run this script)"
echo "5. git add . && git commit -m 'Update fork + reapply GitHub Pages config'"
echo "6. git push origin main"
echo ""
echo "NOTES:"
echo "- First deploy: some images may be 404 until GitHub Pages builds completely (or probably until 2nd deploy)"
echo "- Dev mode locally: font loading might have issues due to pathPrefix - normal behavior"
echo "- Script is reusable for future upstream updates (maybe)"
echo ""
echo "Script version: 1.0.0-alpha.4 - September 4th, 2025"
echo ""