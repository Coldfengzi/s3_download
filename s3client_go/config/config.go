package config

import "github.com/BurntSushi/toml"

type Config struct {
    Server ServerConfig `toml:"server"`
    S3     S3Config     `toml:"s3"`
}

type ServerConfig struct {
    Port         int     `toml:"port"`
    PathName     string  `toml:"location"`
}

type S3Config struct {
    Endpoint     string `toml:"endpoint"`
    AccessKey    string `toml:"access_key"`
    SecretKey    string `toml:"secret_key"`
    Region       string `toml:"region"`
    UsePathStyle bool   `toml:"use_path_style"`
    Bucket       string `toml:"bucket"`
}

func Load(path string) (*Config, error) {
    var cfg Config
    _, err := toml.DecodeFile(path, &cfg)
    return &cfg, err
}
