<!--
SPDX-FileCopyrightText: 2023 Slavi Pantaleev
SPDX-FileCopyrightText: 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Jitsi Ansible role

[![REUSE status](https://api.reuse.software/badge/github.com/mother-of-all-self-hosting/ansible-role-jitsi)](https://api.reuse.software/info/github.com/mother-of-all-self-hosting/ansible-role-jitsi)

This is an [Ansible](https://www.ansible.com/) role which installs [Jitsi](https://jitsi.org/) to run as a bunch of [Docker](https://www.docker.com/) containers wrapped in systemd services. The architecture is inspired by the [docker-jitsi-meet](https://github.com/jitsi/docker-jitsi-meet) project, but does not use Docker Compose.

This role *implicitly* depends on:

- [`com.devture.ansible.role.playbook_help`](https://github.com/devture/com.devture.ansible.role.playbook_help)
- [`com.devture.ansible.role.systemd_docker_base`](https://github.com/devture/com.devture.ansible.role.systemd_docker_base)

For an Ansible playbook which integrates this role and makes it easier to use, see the [mash-playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

💡 See this [document](docs/configuring-jitsi.md) for details about setting up the service with this role.
