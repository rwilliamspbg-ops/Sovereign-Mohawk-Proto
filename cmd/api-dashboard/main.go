// Copyright 2026 Sovereign-Mohawk Core Team
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
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
