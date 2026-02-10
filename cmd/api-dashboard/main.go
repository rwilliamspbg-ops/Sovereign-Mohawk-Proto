package main

import (
	"encoding/json"
	"log"
	"net/http"
)

type NetworkOverview struct {
	TotalNodes  int `json:"total_nodes"`
	OnlineNodes int `json:"online_nodes"`
	TasksToday  int `json:"tasks_today"`
}

func main() {
	http.Handle("/", http.FileServer(http.Dir("static")))

	http.HandleFunc("/api/overview", func(w http.ResponseWriter, r *http.Request) {
		resp := NetworkOverview{
			TotalNodes:  3,
			OnlineNodes: 2,
			TasksToday:  5,
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	})

	log.Println("api-dashboard listening on :8081")
	log.Fatal(http.ListenAndServe(":8081", nil))
}
