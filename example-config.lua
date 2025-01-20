config = {

    log = {
        level = "info",
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
        {
            name = "test_ns",
            domain = "example.com",
            provider = "namesilo",
            auth = {
                apikey = "your api key",
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
                    },
                },
            },
        },
        {
            name = "test_ali",
            domain = "example.com",
            provider = "aliyun",
            auth = {
                ak_id = "your ak id",
                ak_secret = "your ak secret",
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
                    },
                },
            },
        },
    },
}
