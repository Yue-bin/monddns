config = {
    log = {
        level = "info",
        path = "./monddns.log",
    },
    confs = {
        {
            name = "test_cf",
            domain = "example.com",
            service_provider = "cloudflare",
            auth = {
                api_token = "your_api_token",
            },
            subs = {
                {
                    sub_domain = "test",
                    ip_list = {
                        {
                            type = "A",
                            method = "url",
                            url = "https://v4.ident.me",
                        },
                        {
                            type = "AAAA",
                            method = "url",
                            url = "https://v6.ident.me",
                        },
                    },
                },
                {
                    sub_domain = "v4.test",
                    ip_list = {
                        {
                            type = "A",
                            method = "url",
                            url = "https://v4.ident.me",
                        },
                    },
                },
                {
                    sub_domain = "lan.test",
                    ip_list = {
                        {
                            type = "A",
                            method = "cmd",
                            cmd =
                            [[ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -n 1]],
                        },
                    },
                },
            },
        },
    }
}
