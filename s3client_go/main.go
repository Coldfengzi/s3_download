package main

import (
    "fmt"
    "log"
    "net/http"

    "s3-server/config"
    "s3-server/handler"
    s3client "s3-server/s3"

    "github.com/gorilla/mux"
)

func main() {
    cfg, err := config.Load("config.toml")
    if err != nil {
        log.Fatal(err)
    }

    s3c, err := s3client.New(
        cfg.S3.Endpoint,
        cfg.S3.AccessKey,
        cfg.S3.SecretKey,
        cfg.S3.Region,
        cfg.S3.UsePathStyle,
    )
    if err != nil {
        log.Fatal(err)
    }

    downloadHandler := &handler.DownloadHandler{
        S3:     s3c,
        Bucket: cfg.S3.Bucket,
    }


    pathName := fmt.Sprintf("%s/{object:.*}", cfg.Server.PathName)
    r := mux.NewRouter()
    r.HandleFunc(pathName, downloadHandler.Download).Methods("GET")

    addr := fmt.Sprintf(":%d", cfg.Server.Port)
    log.Printf("Listening on :%d%s", cfg.Server.Port, cfg.Server.PathName)
    log.Fatal(http.ListenAndServe(addr, r))
}
