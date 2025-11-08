#!/bin/bash
# 🌈 GitHub Uploader Plus v4.1.5 — Neon Glow Intelligence Fusion
# Termux-ready | Auto README + LICENSE | HTTPS + SSH Upload Support

set -e
set -o pipefail

# === STYLE ===
BLUE=$(tput setaf 6); GREEN=$(tput setaf 2); RED=$(tput setaf 1)
YELLOW=$(tput setaf 3); MAGENTA=$(tput setaf 5); CYAN=$(tput setaf 4)
BOLD=$(tput bold); RESET=$(tput sgr0)
clear_screen(){ printf "\033c"; }
pause(){ echo; read -r -p "Tekan ENTER untuk kembali ke menu utama..."; }

# === DEPENDENCIES ===
ensure_pkg(){
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "${YELLOW}Menginstal $1...${RESET}"
    pkg install -y "$1" >/dev/null 2>&1 || true
  fi
}
for dep in git curl jq figlet; do ensure_pkg "$dep"; done
if ! command -v lolcat >/dev/null 2>&1; then
  ensure_pkg ruby; gem install lolcat >/dev/null 2>&1 || true
fi

# === SAFE DIR FIX ===
safe_dir_fix(){ git config --global --add safe.directory "$1" >/dev/null 2>&1; }

# === LICENSE (GitHub-Compatible Templates) ===
generate_license() {
  local type="$1" author="$2" year=$(date +%Y)
  case "$type" in
    mit)
      cat <<EOF
MIT License

Copyright (c) $year $author

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
      ;;
    apache-2.0)
      cat <<EOF
Apache License
Version 2.0, January 2004
http://www.apache.org/licenses/

Copyright (c) $year $author

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
EOF
      ;;
    gpl-3.0)
      cat <<EOF
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

Copyright (C) $year $author

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
EOF
      ;;
    unlicense)
      cat <<EOF
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or distribute this
software, either in source code form or as a compiled binary, for any purpose,
commercial or non-commercial, and by any means.

In jurisdictions that recognize copyright laws, the author or authors of this
software dedicate any and all copyright interest in the software to the public
domain. We make this dedication for the benefit of the public at large and to
the detriment of our heirs and successors. We intend this dedication to be an
overt act of relinquishment in perpetuity of all present and future rights to
this software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
EOF
      ;;
    *)
      echo "No license selected." ;;
  esac
}


# === README ===
generate_readme(){
  local path="$1" repo="$2" desc="$3" username="$4" banner="$5" license="$6"
  local now=$(date '+%A, %d %B %Y — %H:%M:%S')
  local banner_ascii=$(figlet -f slant "$banner" 2>/dev/null || echo "$banner")
  mkdir -p "$path"
  
  # buat struktur folder bergaya tree
  echo "📦 Membuat struktur folder..." 
  local tree_output
  if command -v tree >/dev/null 2>&1; then
    tree_output=$(tree -a -I '.git|node_modules' "$path")
  else
    tree_output=$(find "$path" -print | sed -e "s|[^/]*/|├── |g")
  fi

  cat > "$path/README.md" <<EOF
# ⚡ $repo

$desc

🕒 Dibuat: $now  
👤 Pemilik: [$username](https://github.com/$username)  
⚖️ Lisensi: ${license:-None}

\`\`\`
$banner_ascii
\`\`\`

---

## 📂 Struktur Folder
\`\`\`
${tree_output}
\`\`\`

Dibuat otomatis oleh **GitHub Uploader Plus v4.1.5 BY CPM_JHON — Neon Glow Intelligence Fusion**
EOF
}

license_template_from_choice(){
  case "$1" in
    1) echo "mit" ;;
    2) echo "apache-2.0" ;;
    3) echo "gpl-3.0" ;;
    4) echo "unlicense" ;;
    *) echo "" ;;
  esac
}

# === API UPLOAD ===
upload_api_file(){
  local username="$1" token="$2" repo="$3" root="$4" rel="$5" msg="$6"
  local file="$root/$rel"
  [ ! -f "$file" ] && return 1
  local size=$(stat -c%s "$file" 2>/dev/null || echo 0)
  [ "$size" -gt 900000 ] && { echo "⚠️  Skip $rel (>900KB)"; return 0; }
  local encoded=$(base64 "$file" | tr -d '\n' || true)
  [ -z "$encoded" ] && return 1
  local sha=$(curl -s -u "${username}:${token}" \
    "https://api.github.com/repos/${username}/${repo}/contents/${rel}" \
    | jq -r '.sha // empty')
  local payload
  if [ -n "$sha" ]; then
    payload="{\"message\":\"$msg\",\"content\":\"$encoded\",\"sha\":\"$sha\"}"
  else
    payload="{\"message\":\"$msg\",\"content\":\"$encoded\"}"
  fi
  curl -s -X PUT -u "${username}:${token}" \
    -H "Accept: application/vnd.github.v3+json" \
    -d "$payload" \
    "https://api.github.com/repos/${username}/${repo}/contents/${rel}" >/dev/null
}

upload_via_api(){
  local username="$1" token="$2" repo="$3" folder="$4" msg="$5"
  cd "$folder" || return
  mapfile -t files < <(find . -type f | sed 's|^\./||')
  local total=${#files[@]} i=0
  echo "${YELLOW}📦 Mengunggah file via API...${RESET}"
  for rel in "${files[@]}"; do
    i=$((i+1))
    printf "\r📤 [%d/%d] %s" "$i" "$total" "$rel"
    upload_api_file "$username" "$token" "$repo" "$(pwd)" "$rel" "$msg"
  done
  echo; echo "${GREEN}✅ Upload selesai!${RESET}"
}

# === CREATE REPO + AUTO UPLOAD ===
create_repo_flow(){
  clear_screen
  figlet -f slant "GitHub Uploader" | (command -v lolcat >/dev/null 2>&1 && lolcat || cat)
  echo "${MAGENTA}=== CREATE REPOSITORY (Auto Upload) ===${RESET}"
  read -p "Masukkan username GitHub: " username
  read -s -p "Masukkan PAT (token): " token; echo
  read -p "Nama repository: " repo
  read -p "Deskripsi singkat repo: " desc
  echo "Pilih lisensi:"
  echo "1) MIT"; echo "2) Apache-2.0"; echo "3) GPL-3.0"; echo "4) Unlicense"; echo "5) None"
  read -p "#? " lchoice
  lic_template=$(license_template_from_choice "$lchoice")

  [ -n "$lic_template" ] && payload="{\"name\":\"$repo\",\"description\":\"$desc\",\"license_template\":\"$lic_template\",\"auto_init\":true}" \
                         || payload="{\"name\":\"$repo\",\"description\":\"$desc\",\"auto_init\":true}"

  echo "${YELLOW}🚀 Membuat repository...${RESET}"
  curl -s -u "${username}:${token}" -d "$payload" "https://api.github.com/user/repos" >/dev/null
  echo "${GREEN}✅ Repository berhasil dibuat.${RESET}"

  read -p "Masukkan path folder lokal proyek: " folder
  mkdir -p "$folder"
  read -p "Masukkan teks banner README: " banner_text
  generate_readme "$folder" "$repo" "$desc" "$username" "$banner_text" "${lic_template:-None}"
  [ -n "$lic_template" ] && generate_license "$lic_template" "$username" > "$folder/LICENSE"

  echo "${CYAN}📤 Upload README & LICENSE...${RESET}"
  upload_api_file "$username" "$token" "$repo" "$folder" "README.md" "Initial README"
  [ -f "$folder/LICENSE" ] && upload_api_file "$username" "$token" "$repo" "$folder" "LICENSE" "Initial LICENSE"
  upload_via_api "$username" "$token" "$repo" "$folder" "Initial project upload"

  echo "${GREEN}✅ Semua upload selesai.${RESET}"
  termux-open-url "https://github.com/${username}/${repo}" >/dev/null 2>&1 || true
  pause
}

# === UPLOAD API MENU ===
upload_menu_flow(){
  read -p "Masukkan username GitHub: " username
  read -s -p "Masukkan PAT (token): " token; echo
  read -p "Nama repository: " repo
  read -p "Masukkan path folder lokal: " folder
  read -p "Pesan commit: " msg
  upload_via_api "$username" "$token" "$repo" "$folder" "$msg"
  pause
}

# === UPLOAD HTTPS / SSH ===
upload_repo(){
  clear
  echo "${MAGENTA}${BOLD}=== UPLOAD / UPDATE REPOSITORY ===${RESET}"
  read -p "Masukkan username GitHub: " username
  read -s -p "Masukkan Personal Access Token (PAT): " token; echo
  read -p "Nama repository: " repo
  echo "Pilih mode upload:"
  echo "1) HTTPS (pakai PAT)"
  echo "2) SSH"
  read -p "#? " mode
  read -p "Masukkan path folder lokal: " path
  read -p "Pesan commit: " msg

  [ ! -d "$path" ] && echo "${RED}❌ Folder tidak ditemukan.${RESET}" && sleep 2 && main_menu && return

  cd "$path" || { echo "${RED}❌ Tidak dapat masuk folder.${RESET}"; sleep 2; main_menu; return; }

  # Pastikan tidak ada repo lama bentrok
  if [ -d ".git" ]; then
    echo "${YELLOW}⚠️  Menghapus konfigurasi Git lama...${RESET}"
    rm -rf .git
  fi

  safe_dir_fix "$path"
  git init --initial-branch=main >/dev/null 2>&1
  git add . >/dev/null 2>&1
  git commit -m "$msg" >/dev/null 2>&1

  # Animasi progress
  animate_push(){
    local spin='|/-\'
    local i=0
    while kill -0 "$1" 2>/dev/null; do
      i=$(( (i+1) %4 ))
      printf "\r${CYAN}🚀 Uploading via Git ${spin:$i:1}${RESET}"
      sleep 0.2
    done
  }

  if [ "$mode" == "1" ]; then
    read -p "Masukkan URL repo HTTPS (https://github.com/user/repo.git): " repo_url
    if [[ ! "$repo_url" =~ ^https://github.com/ ]]; then
      echo "${RED}❌ URL tidak valid.${RESET}"; sleep 2; main_menu; return
    fi
    git remote add origin "https://${username}:${token}@${repo_url#https://}"
    echo "${CYAN}Mengunggah via HTTPS...${RESET}"
    (git push --set-upstream origin main -f >/dev/null 2>&1) & pid=$!
    animate_push $pid
    wait $pid
    if [ $? -eq 0 ]; then
      echo -e "\n${GREEN}✅ Upload HTTPS berhasil!${RESET}"
    else
      echo -e "\n${RED}❌ Upload HTTPS gagal.${RESET}"
    fi

  elif [ "$mode" == "2" ]; then
    read -p "Masukkan URL repo SSH (git@github.com:user/repo.git): " ssh_url
    if [[ ! "$ssh_url" =~ ^git@github.com: ]]; then
      echo "${RED}❌ URL SSH tidak valid.${RESET}"; sleep 2; main_menu; return
    fi
    git remote add origin "$ssh_url"
    echo "${CYAN}Mengunggah via SSH...${RESET}"
    (git push --set-upstream origin main -f >/dev/null 2>&1) & pid=$!
    animate_push $pid
    wait $pid
    if [ $? -eq 0 ]; then
      echo -e "\n${GREEN}✅ Upload SSH berhasil!${RESET}"
    else
      echo -e "\n${RED}❌ Upload SSH gagal.${RESET}"
    fi
  fi

  echo
  echo "${BLUE}🌐 Membuka repo di browser...${RESET}"
  termux-open-url "https://github.com/${username}/${repo}" >/dev/null 2>&1 || true
  pause
}

# ========== DELETE REPO ==========
delete_repo() {
  clear
  echo "╔════════════════════════════════════╗"
  echo "║   ❌ DELETE REPOSITORY             ║"
  echo "╚════════════════════════════════════╝"
  read -p "Masukkan username GitHub: " username
  echo -n "Masukkan PAT (token): "; read -s token; echo
  read -p "Nama repository: " repo
  read -p "Ketik nama repo lagi untuk konfirmasi: " conf
  if [ "$conf" != "$repo" ]; then echo "${RED}Batal.${RESET}"; sleep 1; main_menu; return; fi
  read -p "Ketik HAPUS untuk konfirmasi akhir: " final
  [ "$final" != "HAPUS" ] && { echo "${RED}Batal.${RESET}"; sleep 1; main_menu; return; }
  curl -s -X DELETE -u "${username}:${token}" "https://api.github.com/repos/${username}/${repo}" \
    && echo "${GREEN}✅ Repo dihapus.${RESET}" || echo "${RED}❌ Gagal.${RESET}"
  read -p "Tekan ENTER untuk kembali..."
  main_menu
}


# === MAIN MENU ===
main_menu(){
  while true; do
    clear_screen
    figlet -f slant "GitHub Uploader" | (command -v lolcat >/dev/null 2>&1 && lolcat || cat)
    echo "${MAGENTA}╔════════════════════════════════════╗"
    echo "║   🌐 GITHUB UPLOADER PLUS v4.1.5   ║"
    echo "║     ⚡ Neon Glow Intelligence ⚡    ║"
    echo "╚════════════════════════════════════╝${RESET}"
    echo "1) 🏗️  Buat Repository Baru"
    echo "2) 📤 Upload / Update Repo (API)"
    echo "3) 🔗 Upload (HTTPS/SSH)"
    echo "4) ❌ Hapus Repository"
    echo "5) 🚪 Keluar"
    echo
    read -p "Pilih opsi: " opt
    case "$opt" in
      1) create_repo_flow ;;
      2) upload_menu_flow ;;
      3) upload_repo ;;
      4) delete_repo ;;
      5) echo "${GREEN}Sampai jumpa!${RESET}"; clear; exit 0 ;;
      *) echo "${RED}Pilihan tidak valid!${RESET}"; sleep 1 ;;
    esac
  done
}

main_menu
