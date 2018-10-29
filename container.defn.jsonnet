local common = import "common.ccf-conf.jsonnet";
local context = import "context.ccf-facts.json";
local containerSecrets = import "grafana.secrets.jsonnet";
local prometheusConf = import "prometheus.conf.jsonnet";

local webServicePort = 3000;
local webServicePortInContainer = webServicePort;

{
	"docker-compose.yml" : std.manifestYamlDoc({
		version: '3.4',

		services: {
			container: {
				container_name: context.containerName,
				image: 'grafana/grafana',
				restart: 'always',
				ports: [webServicePort + ':' + webServicePortInContainer],
				networks: ['network'],
				volumes: [
					'storage:/var/lib/grafana',
					context.containerRuntimeConfigHome + '/provisioning:/etc/grafana/provisioning',
				],
				environment: [
					"GF_DEFAULT_INSTANCE_NAME=" + common.applianceName,
					"GF_SECURITY_ADMIN_USER=" + containerSecrets.adminUser,
					"GF_SECURITY_ADMIN_PASSWORD=" + containerSecrets.adminPassword,
					"GF_USERS_ALLOW_SIGN_UP=false"
				],
				labels: {
					'traefik.enable': 'true',
					'traefik.docker.network': common.defaultDockerNetworkName,
					'traefik.domain': context.containerName + '.' + common.applianceFQDN,
					'traefik.backend': context.containerName,
					'traefik.frontend.entryPoints': 'http,https',
					'traefik.frontend.rule': 'Host:' + context.containerName + '.' + common.applianceFQDN,
				}
			},
		},

		networks: {
			network: {
				external: {
					name: common.defaultDockerNetworkName
				},
			},
		},

		volumes: {
			storage: {
				name: context.containerName
			},
		},
	}),

	"after_configure.make-plugin.sh": |||
		#!/bin/bash
		GRAFANA_PROV_DASHBOARDS_HOME=etc/provisioning/dashboards
		echo "Replacing DS_PROMETHEUS with 'Prometheus' in $GRAFANA_PROV_DASHBOARDS_HOME"
		sed -i 's/$${DS_PROMETHEUS}/Prometheus/g' $GRAFANA_PROV_DASHBOARDS_HOME/*.json
	|||,

	"etc/provisioning/datasources/prometheus.yml" : std.manifestYamlDoc({
		apiVersion: 1,
		datasources: [
			{
				name: "Prometheus",
				type: "prometheus",
				access: "proxy",
				url: 'http://' + context.DOCKER_HOST_IP_ADDR + ":" + prometheusConf.webServicePort
			},
		],
	}),
}