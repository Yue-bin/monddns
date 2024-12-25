config = {

    log = {
        level = "trace",
        path = "/var/log/monddns.log",
    },
    confs = {
        {
            name = "test_cf",
            domain = "example.com",
            provider = "cloudflare",
            auth = {
                api_token = "api token",
            },
            subs = {
                {
                    sub_domain = "test",
                    ip_list = {
                        {
                            type = "A",
                            method = "static",
                            content = "8.8.8.8",
                        },
                        {
                            type = "A",
                            method = "url",
                            content = "https://v4.ident.me",
                        },
                        {
                            type = "AAAA",
                            method = "static",
                            content = "::1",
                        },
                        {
                            type = "AAAA",
                            method = "url",
                            content = "https://v6.ident.me",
                        },
                    },
                },
                {
                    sub_domain = "v4.test",
                    ip_list = {
                        {
                            type = "A",
                            method = "url",
                            content = "https://v4.ident.me",
                        },
                    },
                },
                {
                    sub_domain = "lan.test",
                    ip_list = {
                        {
                            type = "A",
                            method = "cmd",
                            content =
                            [[ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -n 1]],
                        },
                    },
                },
                {
                    sub_domain = "static.test",
                    ip_list = {
                        {
                            type = "A",
                            method = "static",
                            content = "8.8.8.8",
                        },
                    },
                }
            },
        },
    }
}
