
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# detect MSYS2 mingw64 location and use it for QT paths

# C:\msys64\mingw64\share\qt6\bin

MINGW_ROOT=/mingw64
MINGW_BIN="${MINGW_ROOT}/bin"
QT_BIN="${MINGW_ROOT}/share/qt6/bin"

echo "MINGW_ROOT: ${MINGW_ROOT}"
echo "MINGW_BIN: ${MINGW_BIN}"
echo "QT_BIN: ${QT_BIN}"

mkdir chiaki-ng-Win
cp build/gui/chiaki.exe chiaki-ng-Win/
export PATH="${SCRIPT_DIR}/build/third-party/cpp-steam-tools:${QT_BIN}:${MINGW_BIN}:${PATH}"
export QT_PLUGIN_PATH="${MINGW_ROOT}/share/qt6/plugins"
export QML2_IMPORT_PATH="${MINGW_ROOT}/share/qt6/qml"
echo chiaki-ng-Win/chiaki.exe > tmp0.txt
while [ -e tmp0.txt ]
do
cp tmp0.txt tmp.txt
rm tmp0.txt
sort -u tmp.txt -o tmp.txt
ldd $(<tmp.txt) | grep -v ":" | cut -d " " -f3 | grep -iv "system32" | grep -iv "not" | xargs -d $'\n' sh -c 'for arg do if [ -n "$arg" ] && [ ! -e "chiaki-ng-Win/${arg##*/}" ]; then echo "Copied $arg"; cp "$arg" chiaki-ng-Win/ ; echo "$arg" >> tmp0.txt; fi; done'
done
# windeployqt6.exe --no-translations --qmldir=gui/src/qml chiaki-ng-Win/chiaki.exe
"$MINGW_ROOT/bin/windeployqt6.exe" --verbose 2 --no-translations --qmldir="${SCRIPT_DIR}/gui/src/qml" chiaki-ng-Win/chiaki.exe
