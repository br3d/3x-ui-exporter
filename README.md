# 3X-UI Exporter

[![Go Report Card](https://goreportcard.com/badge/github.com/wi1dcard/v2ray-exporter)][goreportcard]
[![Build Status](https://app.travis-ci.com/wi1dcard/v2ray-exporter.svg?branch=master)][build-status]

An exporter that collects 3X-UI (V2Ray/Xray) metrics over its [Stats API][stats-api] and exports them to Prometheus.

- [3X-UI Exporter](#3x-ui-exporter)
  - [Quick Start](#quick-start)
    - [Binaries](#binaries)
    - [Third-party Packages](#third-party-packages)
    - [Docker (Recommended)](#docker-recommended)
    - [Grafana Dashboard](#grafana-dashboard)
  - [Tutorial](#tutorial)
  - [Digging Deeper](#digging-deeper)
  - [TODOs](#todos)
  - [Special Thanks](#special-thanks)
  - [License](#license)

![][grafana-screenshot]

[stats-api]: https://www.v2ray.com/chapter_02/stats.html
[goreportcard]: https://goreportcard.com/report/github.com/wi1dcard/v2ray-exporter
[grafana-screenshot]: https://i.loli.net/2020/06/12/KzjOnyu93VEIPiW.png
[build-status]: https://app.travis-ci.com/github/wi1dcard/v2ray-exporter

## Quick Start

### Docker (Recommended)

You can pull the container image from GitHub Container Registry:

```bash
docker pull ghcr.io/br3d/3x-ui-exporter:latest
```

Or find the docker images built automatically by CI from [Docker Hub](https://github.com/br3d/3x-ui-exporter/pkgs/container/3x-ui-exporter). The images are made for multi-arch. You can run it from your Raspberry Pi or any other ARM, ARM64 devices without changing the image name:

```bash
docker run --rm -it ghcr.io/br3d/3x-ui-exporter:latest
```

Please note that `latest` tag is not available on Docker Hub. Use `master` instead if you want the latest build of master branch.

### Grafana Dashboard

A simple Grafana dashboard is also available [here][grafana-dashboard]. Please refer to the [Grafana docs][grafana-importing-dashboard] to get the steps of importing dashboards from JSON files.

Note that the dashboard on [grafana.com][grafana-dashboard-grafana-dot-com] may not be the latest version, please consider downloading the dashboard JSON from the link above.

## Tutorial

Before we start, let's assume you have already set up Prometheus and Grafana.

Firstly, you will need to make sure the API and statistics related features have been enabled in your 3X-UI (V2Ray/Xray) config file. For example:

```json
{
    "stats": {},
    "api": {
        "tag": "api",
        "services": [
            "StatsService"
        ]
    },
    "policy": {
        "levels": {
            "0": {
                "statsUserUplink": true,
                "statsUserDownlink": true
            }
        },
        "system": {
            "statsInboundUplink": true,
            "statsInboundDownlink": true,
            "statsOutboundUplink": true,
            "statsOutboundDownlink": true
        }
    },
    "inbounds": [
        {
            "tag": "tcp",
            "port": 12345,
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "email": "foo@example.com",
                        "id": "e731f153-4f31-49d3-9e8f-ff8f396135ef",
                        "level": 0,
                        "alterId": 4
                    },
                    {
                        "email": "bar@example.com",
                        "id": "e731f153-4f31-49d3-9e8f-ff8f396135ee",
                        "level": 0,
                        "alterId": 4
                    }
                ]
            }
        },
        {
            "tag": "api",
            "listen": "127.0.0.1",
            "port": 8080,
            "protocol": "dokodemo-door",
            "settings": {
                "address": "127.0.0.1"
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        }
    ],
    "routing": {
        "rules": [
            {
                "inboundTag": [
                    "api"
                ],
                "outboundTag": "api",
                "type": "field"
            }
        ]
    }
}
```

As you can see, we opened two inbounds in the configuration above. The first inbound accepts VMess connections from user `foo@example.com` and `bar@example.com`, and the second one listens port 8080 on localhost and handles the API calls, which is the endpoint that the exporter scrapes. If you'd like to run 3X-UI and exporter on different machines, consider use `0.0.0.0` instead of `127.0.0.1` and be careful with the security risks.

Additionally, you should also enable `stats`, `api`, and `policy` settings, and setup proper routing rules in order to get traffic statistics works. For more information, please visit [The Beginner's Guide of V2Ray][v2ray-beginners-guide].

The next step is to start the exporter:

```bash
3xui-exporter --v2ray-endpoint "127.0.0.1:8080"
## Or
docker run --rm -d wi1dcard/v2ray-exporter:master --v2ray-endpoint "127.0.0.1:8080"
```

The logs signifies that the exporter started to listening on the default address (`:9550`).

```plain
3X-UI Exporter master-39eb972 (built 2020-04-05T05:32:01Z)
time="2020-05-11T06:18:09Z" level=info msg="Server is ready to handle incoming scrape requests."
```

Use `--listen` option if you'd like to changing the listen address or port. You can now open `http://IP:9550` in your browser:

![browser.png][browser-screenshot]

The exporter provides two endpoints:
- `/metrics` - Exporter's own metrics
- `/scrape` - 3X-UI (V2Ray/Xray) metrics

Click the `Scrape V2Ray Metrics` and the exporter will expose all metrics including 3X-UI runtime and statistics data in the Prometheus metrics format, for example:

```
...
# HELP xray_up Indicate scrape succeeded or not
# TYPE xray_up gauge
xray_up 1
# HELP xray_uptime_seconds 3X-UI uptime in seconds
# TYPE xray_uptime_seconds gauge
xray_uptime_seconds 150624
...
```

If `xray_up 1` doesn't exist in the response, that means the scrape was failed, please check out the logs (STDOUT or STDERR) of 3X-UI Exporter for more detailed information.

We have the metrics exposed. Now let Prometheus scrapes these data points and visualize them with Grafana. Here is an example Promtheus configuration:

```yaml
global:
  scrape_interval: 15s
  scrape_timeout: 5s

scrape_configs:
  - job_name: 3xui
    metrics_path: /scrape
    static_configs:
      - targets: [IP:9550]
```

To learn more about Prometheus, please visit the [official docs][prometheus-docs].

## Digging Deeper

The exporter doesn't retain the original metric names from 3X-UI intentionally. You may find out why in the [comments][explaination-of-metric-names].

For users who do not really care about the internal changes, but only need a mapping table, here it is:

| Runtime Metric   | Exposed Metric                     |
| :--------------- | :--------------------------------- |
| `uptime`         | `xray_uptime_seconds`             |
| `num_goroutine`  | `xray_goroutines`                 |
| `alloc`          | `xray_memstats_alloc_bytes`       |
| `total_alloc`    | `xray_memstats_alloc_bytes_total` |
| `sys`            | `xray_memstats_sys_bytes`         |
| `mallocs`        | `xray_memstats_mallocs_total`     |
| `frees`          | `xray_memstats_frees_total`       |
| `live_objects`   | Removed. See the appendix below.   |
| `num_gc`         | `xray_memstats_num_gc`            |
| `pause_total_ns` | `xray_memstats_pause_total_ns`    |

| Statistic Metric                          | Exposed Metric                                                              |
| :---------------------------------------- | :-------------------------------------------------------------------------- |
| `inbound>>>tag-name>>>traffic>>>uplink`   | `xray_traffic_uplink_bytes_total{dimension="inbound",target="tag-name"}`   |
| `inbound>>>tag-name>>>traffic>>>downlink` | `xray_traffic_downlink_bytes_total{dimension="inbound",target="tag-name"}` |
| `outbound>>>tag-name>>>traffic>>>uplink`   | `xray_traffic_uplink_bytes_total{dimension="outbound",target="tag-name"}`   |
| `outbound>>>tag-name>>>traffic>>>downlink` | `xray_traffic_downlink_bytes_total{dimension="outbound",target="tag-name"}` |
| `user>>>user-email>>traffic>>>uplink`     | `xray_traffic_uplink_bytes_total{dimension="user",target="user-email"}`    |
| `user>>>user-email>>>traffic>>>downlink`  | `xray_traffic_downlink_bytes_total{dimension="user",target="user-email"}`  |
| ...                                       | ...                                                                         |

- The value of `live_objects` can be calculated by `memstats_mallocs_total - memstats_frees_total`.

## TODOs

- GitHub Action

## Special Thanks

- <https://github.com/schweikert/fping-exporter>
- <https://github.com/oliver006/redis_exporter>
- <https://github.com/roboll/helmfile>

## License

MIT

[github-releases]: https://github.com/wi1dcard/v2ray-exporter/releases
[v2ray-beginners-guide]: https://guide.v2fly.org/en_US/advanced/traffic.html
[browser-screenshot]: https://i.loli.net/2020/01/11/ZVtNEU8iqMrFGKm.png
[prometheus-docs]: https://prometheus.io/docs/prometheus/latest/configuration/configuration/
[grafana-dashboard]: ./dashboard.json
[grafana-dashboard-grafana-dot-com]: https://grafana.com/grafana/dashboards/11545
[grafana-importing-dashboard]: https://grafana.com/docs/grafana/latest/reference/export_import/#importing-a-dashboard
[explaination-of-metric-names]: https://github.com/wi1dcard/v2ray-exporter/blob/110e82dfefb1b51f4da3966ddd1945b5d0dac203/exporter.go#L134
