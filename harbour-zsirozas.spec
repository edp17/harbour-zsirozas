Name: harbour-zsirozas
Version: 1.0.0
Release: 0.8.0
Summary: Hungarian Fat Card Game (Zsir, Zsirozas)
License: MIT
URL: https://github.com/edp17/harbour-zsirozas
Source0: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-root

Requires:       sailfishsilica-qt5
BuildRequires:  pkgconfig(sailfishapp)
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  qt5-qttools-linguist

%description
Zsirozas — The Hungarian Fat Card (Zsirozas) game ported to Sailfish OS.

%prep
%setup -q

%build
mkdir -p build
cd build
cmake .. \
  -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

%install
rm -rf %{buildroot}

# ----------------------------
# Install binary
# ----------------------------
mkdir -p %{buildroot}/usr/bin
install -m 755 build/harbour-zsirozas %{buildroot}/usr/bin/

# ----------------------------
# Install QML files under qml/
# SailfishApp expects: /usr/share/<appname>/qml/harbour-zsirozas.qml
# ----------------------------
mkdir -p %{buildroot}/usr/share/%{name}/qml
cp -a sailfish/*.qml %{buildroot}/usr/share/%{name}/qml/
cp -a sailfish/*.js %{buildroot}/usr/share/%{name}/qml/ 2>/dev/null || true

# ----------------------------
# Install card images
# ----------------------------
mkdir -p %{buildroot}/usr/share/%{name}/images
cp -a images/cards %{buildroot}/usr/share/%{name}/images/

# ----------------------------
# Install translations
# ----------------------------
mkdir -p %{buildroot}/usr/share/%{name}/translations
install -m 644 build/harbour-zsirozas-hu.qm \
    %{buildroot}/usr/share/%{name}/translations/

# Copy icons into QML folder (optional, for relative paths)
cp -a sailfish/icons %{buildroot}/usr/share/%{name}/qml/

# ----------------------------
# Install desktop file
# ----------------------------
mkdir -p %{buildroot}/usr/share/applications
install -m 644 sailfish/desktop/%{name}.desktop \
    %{buildroot}/usr/share/applications/%{name}.desktop

# ----------------------------
# Install icons into proper icon theme directories
# ----------------------------
mkdir -p %{buildroot}/usr/share/icons/hicolor/256x256/apps

install -m 644 sailfish/icons/icon-256.png \
    %{buildroot}/usr/share/icons/hicolor/256x256/apps/%{name}.png


# ----------------------------
# Install documentation
# ----------------------------
mkdir -p %{buildroot}/usr/share/licenses/%{name}
install -m 644 LICENSE %{buildroot}/usr/share/licenses/%{name}/

%files
%defattr(-,root,root,-)
/usr/bin/%{name}
/usr/share/%{name}
/usr/share/icons/hicolor/256x256/apps/%{name}.png
/usr/share/applications/%{name}.desktop
/usr/share/licenses/%{name}

%changelog
* Thu Sep 03 2026 edp17 - 1.0.0-0.8.0
- Final cleanup for release

* Wed Sep 02 2026 edp17 - 1.0.0-0.7.rc7
- Add Hungarian localization and interrupted-round recovery
- Enlarge and correct the illustrated rules examples
- Finalize About metadata and release documentation

* Wed Sep 02 2026 edp17 - 1.0.0-0.6.rc6
- Align partnership won piles at the table edges
- Add compact illustrated rule examples and a GitHub link

* Wed Sep 02 2026 edp17 - 1.0.0-0.5.rc5
- Polish pile layout, result placement, player-only inspection, grayscale cards, and table scatter
- Calibrate and benchmark a measurable Easy-to-Expert strength progression

* Tue Sep 01 2026 edp17 - 1.0.0-0.4.rc4
- Add traditional four-player partnerships, per-player settings, won-card inspection, and refreshed pages

* Tue Sep 01 2026 edp17 - 1.0.0-0.3.rc3
- Restore optional ordinary hits and fix player-hand flight origin coordinates

* Tue Sep 01 2026 edp17 - 1.0.0-0.2.rc2
- Fix player-card input after dealing and defer pulley New Game until the table settles

* Tue Sep 01 2026 edp17 - 1.0.0-0.1.rc1
- RC1 rules core, AI difficulty levels, deterministic animation sequencing, and tests

* Thu Nov 20 2025 edp17 - 0.1.0-1
- Initial package
