Name: harbour-zsirozas
Version: 0.1.1
Release: 20
Summary: Hungarian Fat Card Game (Zsir, Zsirozas)
License: MIT
URL: https://example.com/harbour-zsirozas
Source0: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-root

Requires:       sailfishsilica-qt5
BuildRequires:  pkgconfig(sailfishapp)
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(packagekitqt5)
BuildRequires:  desktop-file-utils

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
mkdir -p %{buildroot}/usr/share/doc/%{name}
cp README_Sailfish.md \
    %{buildroot}/usr/share/doc/%{name}

%files
%defattr(-,root,root,-)
/usr/bin/%{name}
/usr/share/%{name}
/usr/share/icons/hicolor/256x256/apps/%{name}.png
/usr/share/applications/%{name}.desktop
/usr/share/doc/%{name}
/usr/share/%{name}/images

%changelog
* Thu Nov 20 2025 Your Name - 0.1.0-1
- Initial package