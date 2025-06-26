<!--
SPDX-FileCopyrightText: 2020 - 2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2020 - 2024 MDAD project contributors
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Jitsi

This is an [Ansible](https://www.ansible.com/) role which installs [Jitsi](https://jitsi.org/) to run as a bunch of [Docker](https://www.docker.com/) containers wrapped in systemd services.

See the project's [documentation](https://jitsi.github.io/handbook/) to learn what Jitsi does and why it might be useful to you.

**Note**: the configuration of this role is similar to the one by [docker-jitsi-meet](https://github.com/jitsi/docker-jitsi-meet). You can refer to the [official documentation](https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker/) for Docker deployment.

## Prerequisites

### Check resource requirements

Before proceeding, make sure to check server's requirements recommended by [the official deployment guide](https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-requirements). Please note that Jitsi Meet requires much resource (network bandwidth, RAM, and CPU) and it depends on a lot of factors how much is sufficient for you.

Jitsi Meet is scalable with multiple JVBs ([Jitsi VideoBridge](https://github.com/jitsi/jitsi-videobridge)), and it is possible to provision them on other hosts by utilizing this role on your Ansible playbook. For big meetings the official guide recommends to prefer deploying JVBs to getting huge amount of RAM on the server. See [this section](#set-up-additional-jvbs-for-more-video-conferences-optional) below for instructions about how to set up JVBs.

### Open ports

You may need to open the following ports to your server:

- `4443/tcp` — RTP media fallback over TCP
- `10000/udp` — RTP media over UDP. Depending on your firewall/NAT configuration, incoming RTP packets on port `10000` may have the external IP of your firewall as destination address, due to the usage of STUN in JVB (see [`jitsi_jvb_stun_servers`](../defaults/main.yml)).

Docker automatically opens these ports in the server's firewall, so you likely don't need to do anything. If you use another firewall in front of the server, you may need to adjust it.

To learn more, see the upstream [firewall documentation](https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker/#external-ports).

## Adjusting the playbook configuration

To enable Jitsi with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/matrix.example.com/vars.yml` if you use the [matrix-docker-ansible-deploy (MDAD)](https://github.com/spantaleev/matrix-docker-ansible-deploy) or [Mother-of-All-Self-Hosting (MASH)](https://github.com/mother-of-all-self-hosting/mash-playbook) Ansible playbook.

```yaml
########################################################################
#                                                                      #
# jitsi                                                                #
#                                                                      #
########################################################################

jitsi_enabled: true

########################################################################
#                                                                      #
# /jitsi                                                               #
#                                                                      #
########################################################################
```

### Set the hostname

**Note**: if you use the MDAD Ansible playbook, it installs Jitsi on the `jitsi.` subdomain (`jitsi.example.com`) by default, so this setting is optional.

To serve Jitsi you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
jitsi_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the Jitsi domain to your server.

### Configure Jitsi authentication and guests mode (optional)

By default the Jitsi Meet instance **does not require for anyone to log in, and is open to use without an account**. If you're fine with such an open Jitsi instance, please skip ahead.

If you would like to control who is allowed to start meetings on your instance, you'd need to enable Jitsi's authentication and optionally guests mode. With authentication enabled, all meetings have to be started by a registered user. After the meeting is started by that user, then guests are free to join. If the registered user is not yet present, they are put on hold in individual waiting rooms.

Authentication type must be one of them: `internal` (default), `jwt`, `ldap` or `matrix`. Currently, only `internal`, `ldap` and `matrix` mechanisms are supported by this role.

**Note**: authentication is not tested by playbook's self-checks. We therefore recommend that you would make sure by yourself that authentication is configured properly. To test it, start a meeting at `example.com` on your browser.

#### Authenticate using Jitsi accounts: Auth-Type `internal`

The default authentication mechanism is `internal` auth, which requires a Jitsi account to have been configured.

To enable authentication with a Jitsi account, add the following configuration to your `vars.yml` file. Make sure to replace `USERNAME_…` and `PASSWORD_…` with your own values.

```yaml
jitsi_enable_auth: true
jitsi_enable_guests: true
jitsi_prosody_auth_internal_accounts:
  - username: "USERNAME_FOR_THE_FIRST_USER_HERE"
    password: "PASSWORD_FOR_THE_FIRST_USER_HERE"
  - username: "USERNAME_FOR_THE_SECOND_USER_HERE"
    password: "PASSWORD_FOR_THE_SECOND_USER_HERE"
```

**Note**: if Jitsi account removal function is not integrated into a playbook, these accounts will not be able to be removed from the Prosody server automatically, even if they are removed from your `vars.yml` file subsequently.

#### Authenticate using LDAP: Auth-Type `ldap`

To enable authentication with LDAP, add the following configuration to your `vars.yml` file (adapt to your needs):

```yaml
jitsi_enable_auth: true
jitsi_auth_type: ldap
jitsi_ldap_url: "ldap://ldap.example.com"
jitsi_ldap_base: "OU=People,DC=example.com"
#jitsi_ldap_binddn: ""
#jitsi_ldap_bindpw: ""
jitsi_ldap_filter: "uid=%u"
jitsi_ldap_auth_method: "bind"
jitsi_ldap_version: "3"
jitsi_ldap_use_tls: true
jitsi_ldap_tls_ciphers: ""
jitsi_ldap_tls_check_peer: true
jitsi_ldap_tls_cacert_file: "/etc/ssl/certs/ca-certificates.crt"
jitsi_ldap_tls_cacert_dir: "/etc/ssl/certs"
jitsi_ldap_start_tls: false
```

For more information refer to the [docker-jitsi-meet](https://github.com/jitsi/docker-jitsi-meet#authentication-using-ldap) and the [saslauthd `LDAP_SASLAUTHD`](https://github.com/winlibs/cyrus-sasl/blob/master/saslauthd/LDAP_SASLAUTHD) documentation.

#### Authenticate using Matrix OpenID: Auth-Type `matrix`

> [!WARNING]
> This probably breaks the Jitsi instance on federated Matrix rooms and does not allow sharing conference links with guests.

This authentication method requires [Matrix User Verification Service (UVS)](https://github.com/matrix-org/matrix-user-verification-service). It verifies against Matrix OpenID, and requires a user-verification-service to run. If you use the MDAD playbook, you can refer [this document](https://github.com/spantaleev/matrix-docker-ansible-deploy/blob/master/docs/configuring-playbook-user-verification-service.md) for the instruction about installing UVS.

To enable authentication with Matrix OpenID, add the following configuration to your `vars.yml` file:

```yaml
jitsi_enable_auth: true
jitsi_auth_type: matrix
```

If you install UVS in a different way than the MDAD playbook, you need to add the following configuration to your `vars.yml` file as well. Make sure to replace `UVS_AUTH_TOKEN_HERE` (auth token for Matrix User Verification Service) and `UVS_URL_HERE` (URL where Matrix User Verification Service is hosted) with your own values.

```yaml
jitsi_prosody_auth_matrix_uvs_auth_token: UVS_AUTH_TOKEN_HERE
jitsi_prosody_auth_matrix_uvs_location: UVS_URL_HERE
```

On the MDAD playbook, these two variables are specified by default, so you do not need to add them. See its [`matrix_servers`](https://github.com/spantaleev/matrix-docker-ansible-deploy/blob/master/group_vars/matrix_servers) for details.

**Notes**:

- If you enable UVS for your Matrix homeserver (Synapse), make sure that the Matrix Federation port (usually `8448`) is accessible. See [this section on the documentation on *matrix-docker-ansible-deploy* playbook](https://github.com/spantaleev/matrix-docker-ansible-deploy/blob/master/docs/configuring-playbook-user-verification-service.md#open-matrix-federation-port) for more information.
- See [https://github.com/matrix-org/prosody-mod-auth-matrix-user-verification](https://github.com/matrix-org/prosody-mod-auth-matrix-user-verification) for more details about the authenticaition with Matrix OpenID.

### Configure `JVB_ADVERTISE_IPS` for running behind NAT or on a LAN environment (optional)

When running Jitsi in a LAN environment, or on the public Internet via NAT, the `JVB_ADVERTISE_IPS` environment variable should be set.

This variable allows to control which IP addresses the JVB will advertise for WebRTC media traffic. It is necessary to set it regardless of the use of a reverse proxy, since it's the IP address that will receive the media (audio / video) and not HTTP traffic, hence it's oblivious to the reverse proxy.

If your users are coming in over the Internet (and not over LAN), this will likely be your public IP address. If this is not set up correctly, calls will crash when more than two users join a meeting.

To set the variable, add the following configuration to your `vars.yml` file. Make sure to replace `LOCAL_IP_ADDRESS_OF_THE_HOST_HERE` with a proper value.

```yaml
jitsi_jvb_container_extra_arguments:
  - '--env "JVB_ADVERTISE_IPS=LOCAL_IP_ADDRESS_OF_THE_HOST_HERE"'
```

Check [the official documentation](https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker/#running-behind-nat-or-on-a-lan-environment) for more details about it.

### Additional configurations (optional)

#### Set a maximum number of participants on a Jitsi conference

You can set a maximum number of participants allowed to join a Jitsi conference. By default the number is not specified.

To set it, add the following configuration to your `vars.yml` file (adapt to your needs):

```yaml
jitsi_prosody_max_participants: 4 # example value
```

#### Configure time zone

You can configure the time zone (default: UTC) for the Jitsi instance. To configure it, add the following configuration to your `vars.yml` file (adapt to your needs):

```yaml
jitsi_timezone: America/New_York
```

#### Enable lobby

With a lobby feature enabled, before participants can join the meeting, they must ask the moderator to be let in. This is useful when you're hosting a private conference.

This feature is disabled by default. To enable it, add the following configuration to your `vars.yml` file:

```yaml
jitsi_enable_lobby: true
```

#### Disable Gravatar

In the default Jisti Meet configuration, `gravatar.com` is enabled as an avatar service.

As this will result in third party request leaking data to the Gravatar Service (`gravatar.com`, unless configured otherwise), you can disable it by adding the following configuration to your `vars.yml` file:

```yaml
jitsi_disable_gravatar: true
```

#### Control Etherpad's availability on Jitsi conferences

If the self-hosted Etherpad instance (which can be installed with [this Ansible role of MASH project](https://github.com/mother-of-all-self-hosting/ansible-role-etherpad)) is available, you can configure it so that it will show up in Jitsi conferences.

By default it is disabled, and you can enable it by adding the following configuration to your `vars.yml` file. Make sure to replace `YOUR_ETHERPAD_BASE_URL_HERE` with your Etherpad base URL (e.g. `https://etherpad.example.com` or `https://example.com/etherpad`).

```yaml
jitsi_etherpad_enabled: true
jitsi_etherpad_base: YOUR_ETHERPAD_BASE_URL_HERE
```

**Note**: on the MDAD Ansible playbook this configuration is enabled by default. See its [`matrix_servers`](https://github.com/spantaleev/matrix-docker-ansible-deploy/blob/master/group_vars/matrix_servers) for details.

#### Enable HSTS preloading

If you want to enable [HSTS (HTTP Strict-Transport-Security) preloading](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security#preloading_strict_transport_security), add the following configuration to your `vars.yml` file:

```yaml
jitsi_web_hsts_preload_enabled: true
```

#### Allow/disallow embedding Jitsi Meet

It is possible to control whether embedding Jitsi Meet to a frame on another website will be allowed or not.

By default it is disallowed, and you can allow it by adding the following configuration to your `vars.yml` file:

```yaml
jitsi_web_framing_enabled: true
```

#### Fine tune Jitsi

If you'd like to have Jitsi save up resources, add the following configuration to your `vars.yml` file (adapt to your needs):

```yaml
jitsi_web_config_resolution_width_ideal_and_max: 480
jitsi_web_config_resolution_height_ideal_and_max: 240
jitsi_web_custom_config_extension: |
  config.enableLayerSuspension = true;

  config.disableAudioLevels = true;

  config.channelLastN = 4;
```

These configurations:

- **limit the maximum video resolution**, to save up resources on both server and clients
- **suspend unused video layers** until they are requested again, to save up resources on both server and clients. Read more on this feature on [this blog post](https://jitsi.org/blog/new-off-stage-layer-suppression-feature/).
- **disable audio levels** to avoid excessive refresh of the client-side page and decrease the CPU consumption involved
- **limit the number of video feeds forwarded to each client**, to save up resources on both server and clients. As clients’ bandwidth and CPU may not bear the load, use this setting to avoid lag and crashes. This feature is available by default on other webconference applications such as Office 365 Teams (the number is limited to 4). Read how it works on [this documentation](https://github.com/jitsi/jitsi-videobridge/blob/5ff195985edf46c9399dcf263cb07167f0a2c724/doc/allocation.md).

### Extending the configuration

There are some additional things you may wish to configure about the component.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using these variables:
  - `jitsi_web_custom_interface_config_extension`: custom configuration to be appended to `interface_config.js`, passed to Jitsi Meet
  - `jitsi_web_custom_config_extension`: custom configuration to be injected into `custom-config.js`, passed to Jitsi Meet
  - `jitsi_jvb_custom_config_extension`: custom configuration to be injected into `custom-sip-communicator.properties`, passed to Jitsi Videobridge (JVB)

### Example configurations

Here is an example set of configurations for running a Jitsi instance with:

- hostname: `call.example.com`
- authentication using a Jitsi account (username: `US3RNAME`, password: `passw0rd`)
- guests: allowed
- maximum participants: 6 people
- timezone: Europe/Sofia
- fine tuning with the configurations presented above
- other miscellaneous options (see the [configuration](https://jitsi.github.io/handbook/docs/dev-guide/dev-guide-configuration) and [user guide](https://jitsi.github.io/handbook/docs/user-guide/user-guide-advanced) on the official Jitsi documentation)

```yaml
jitsi_enabled: true
jitsi_hostname: "call.example.com"
jitsi_enable_auth: true
jitsi_enable_guests: true
jitsi_prosody_auth_internal_accounts:
  - username: "US3RNAME"
    password: "passw0rd"
jitsi_prosody_max_participants: 6
jitsi_timezone: Europe/Sofia
jitsi_web_config_resolution_width_ideal_and_max: 480
jitsi_web_config_resolution_height_ideal_and_max: 240
jitsi_web_custom_config_extension: |
  config.enableLayerSuspension = true;
  config.disableAudioLevels = true;
  config.channelLastN = 4;
  config.requireDisplayName = true;
  config.startAudioOnly = true;
```

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MDAD / MASH playbook, the shortcut commands with the [`just` program](https://github.com/spantaleev/matrix-docker-ansible-deploy/blob/master/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

Open the specified URL such as `https://example.com`, and you can start a videoconference. Note that you'll need to log in to your Jitsi's account if you have configured authentication with `internal` auth.

Check [the official user guide](https://jitsi.github.io/handbook/docs/category/user-guide) for details about how to use Jitsi Meet.

### Set up additional JVBs for more video-conferences (optional)

By default, a single JVB ([Jitsi VideoBridge](https://github.com/jitsi/jitsi-videobridge)) is deployed on the same host as the main server. To allow more video-conferences to happen at the same time, you'd need to provision additional JVB services on other hosts.

These settings below will allow you to provision those extra JVB instances. The instances will register themselves with the Prosody service, and be available for Jicofo to route conferences too.

#### Add the `jitsi_jvb_servers` section on `hosts` file

For additional JVBs, you'd need to add the section titled `jitsi_jvb_servers` on the ansible `hosts` file with the details of the JVB hosts as below:

```INI
[jitsi_jvb_servers]
jvb-2.example.com ansible_host=192.168.0.2
```

Make sure to replace `jvb-2.example.com` with your hostname for the JVB and `192.168.0.2` with your JVB's external IP address, respectively.

You could add JVB hosts as many as you would like. When doing so, add lines with the details of them.

#### Prepare `vars.yml` files for additional JVBs

If the main server is `example.com` and the additional JVB instance is going to be deployed at `jvb-2.example.com`, the variables for the latter need to be specified on `vars.yml` in its directory (`inventory/host_vars/jvb-2.example.com`).

Note that most (if not all) variables are common for both servers.

If you are setting up multiple JVB instances, you'd need to create `vars.yml` files for each of them too (`inventory/host_vars/jvb-3.example.com/vars.yml`, for example).

#### Set the server ID to each JVB

Each JVB requires a server ID to be set, so that it will be uniquely identified. The server ID allows Jitsi to keep track of which conferences are on which JVB.

The server ID can be set with the variable `jitsi_jvb_server_id`. It will end up as the `JVB_WS_SERVER_ID` environment variables in the JVB docker container.

To set the server ID to `jvb-2`, add the following configuration to either `hosts` or `vars.yml` files (adapt to your needs).

- On `hosts`:

  Add `jitsi_jvb_server_id=jvb-2` after your JVB's external IP addresses as below:

  ```INI
  [jitsi_jvb_servers]
  jvb-2.example.com ansible_host=192.168.0.2 jitsi_jvb_server_id=jvb-2
  jvb-3.example.com ansible_host=192.168.0.3 jitsi_jvb_server_id=jvb-2
  ```

- On `vars.yml` files:

  ```yaml
  jitsi_jvb_server_id: 'jvb-2'
  ```

Alternatively, you can specify the variable as a parameter to [the ansible command](#run-the-playbook).

**Note**: the server ID `jvb-1` is reserved for the JVB instance running on the main host, therefore should not be used as the ID of an additional JVB host.

#### Set colibri WebSocket port

The additional JVBs will need to expose the colibri WebSocket port.

To expose the port, add the following configuration to your `vars.yml` files:

```yaml
jitsi_jvb_container_colibri_ws_host_bind_port: 9090
```

#### Set Prosody XMPP server

The JVB will also need to know the location of the Prosody XMPP server.

Similar to the server ID (`jitsi_jvb_server_id`), this can be set with the variable for the JVB by using the variable `jitsi_xmpp_server`.

##### Set the main server's hostname

The Jitsi Prosody container is deployed on the main server by default, so the value can be set to the its domain. To set the value, add the following configuration to your `vars.yml` files (adapt to your needs):

```yaml
jitsi_xmpp_server: "example.com"
```

##### Set an IP address of the main server

Alternatively, the IP address of the main server can be set. This can be useful if you would like to use a private IP address.

To set the IP address of the server, add the following configuration to your `vars.yml` files:

```yaml
jitsi_xmpp_server: "192.168.0.1"
```

##### Expose XMPP port

By default, the main server does not expose the XMPP port (`5222`); only the XMPP container exposes it internally inside the host. This means that the first JVB (which runs on the main server) can reach it but the additional JVBs cannot. Therefore, the XMPP server needs to expose the port, so that the additional JVBs can connect to it.

To expose the port and have Docker forward the port, add the following configuration to your `vars.yml` files:

```yaml
jitsi_prosody_container_jvb_host_bind_port: 5222
```

#### Reverse-proxy with Traefik

To make Traefik reverse-proxy to these additional JVBs, add the following configuration to your main `vars.yml` file (`inventory/host_vars/example.com/vars.yml`):

```yaml
# Traefik proxying for additional JVBs. These can't be configured using Docker
# labels, like the first JVB is, because they run on different hosts, so we add
# the necessary configuration to the file provider.
traefik_provider_configuration_extension_yaml: |
  http:
   routers:
     {% for host in groups['jitsi_jvb_servers'] %}

     additional-{{ hostvars[host]['jitsi_jvb_server_id'] }}-router:
       entryPoints:
         - "{{ traefik_entrypoint_primary }}"
       rule: "Host(`{{ jitsi_hostname }}`) && PathPrefix(`/colibri-ws/{{ hostvars[host]['jitsi_jvb_server_id'] }}/`)"
       service: additional-{{ hostvars[host]['jitsi_jvb_server_id'] }}-service
       {% if traefik_entrypoint_primary != 'web' %}

       tls:
         certResolver: "{{ traefik_certResolver_primary }}"

       {% endif %}

     {% endfor %}

   services:
     {% for host in groups['jitsi_jvb_servers'] %}

     additional-{{ hostvars[host]['jitsi_jvb_server_id'] }}-service:
       loadBalancer:
         servers:
           - url: "http://{{ host }}:9090/"

     {% endfor %}
```

#### Run the playbook

After configuring `hosts` and `vars.yml` files, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts --limit jitsi_jvb_servers jitsi_jvb.yml --tags=common,setup-additional-jitsi-jvb,start
```

## Troubleshooting

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running the commands below:

- `journalctl -fu jitsi-web`
- `journalctl -fu jitsi-prosody`
- `journalctl -fu jitsi-jicofo`
- `journalctl -fu jitsi-jvb`

**Note**: these service names depend on how you/your playbook named the service, e.g. `matrix-jitsi-web`.

### `Error: Account creation/modification not supported`

If you get an error like `Error: Account creation/modification not supported` with authentication enabled, it's likely that you had previously installed Jitsi without auth/guest support.

In this case, you should consider to reinstall your Jitsi installation.
