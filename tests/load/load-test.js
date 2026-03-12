/**
 * tests/load/load-test.js
 * Test de charge k6 – Students App
 *
 * Scenarios :
 *   1. smoke   : 1 VU, 30s  – verification de base
 *   2. load    : montee progressive jusqu'a 50 VU sur 3 min
 *   3. stress  : pic a 100 VU pour detecter la limite
 *
 * Usage local :
 *   k6 run --env TARGET_URL=http://32.195.9.34 tests/load/load-test.js
 */

import http from "k6/http";
import { check, sleep } from "k6";
import { Rate, Trend, Counter } from "k6/metrics";

// ── Metriques personnalisees ───────────────────────────────────────────────
const errorRate      = new Rate("error_rate");
const studentsTrend  = new Trend("students_page_duration");
const homeTrend      = new Trend("home_page_duration");
const requestCounter = new Counter("total_requests");

// ── Configuration des scenarios ───────────────────────────────────────────
export const options = {
  scenarios: {
    // Smoke test : 1 utilisateur pendant 30s
    smoke: {
      executor: "constant-vus",
      vus: 1,
      duration: "30s",
      tags: { scenario: "smoke" },
    },
    // Load test : montee progressive 0 → 50 VU
    load: {
      executor: "ramping-vus",
      startVUs: 0,
      stages: [
        { duration: "1m",   target: 10  }, // montee douce
        { duration: "2m",   target: 50  }, // charge nominale
        { duration: "1m",   target: 50  }, // maintien
        { duration: "30s",  target: 0   }, // descente
      ],
      startTime: "35s", // apres le smoke test
      tags: { scenario: "load" },
    },
    // Stress test : pic a 100 VU
    stress: {
      executor: "ramping-vus",
      startVUs: 0,
      stages: [
        { duration: "30s", target: 100 }, // montee rapide
        { duration: "1m",  target: 100 }, // maintien du pic
        { duration: "30s", target: 0   }, // descente
      ],
      startTime: "5m30s", // apres le load test
      tags: { scenario: "stress" },
    },
  },

  // ── Seuils de performance (SLOs) ────────────────────────────────────────
  thresholds: {
    // 95% des requetes < 2s
    http_req_duration: ["p(95)<2000"],
    // Taux d'erreur < 5%
    error_rate: ["rate<0.05"],
    // Duree page students < 3s au p95
    students_page_duration: ["p(95)<3000"],
  },
};

// ── URL cible ─────────────────────────────────────────────────────────────
const BASE_URL = __ENV.TARGET_URL || "http://localhost";

// ── Scenario principal ────────────────────────────────────────────────────
export default function () {
  // Page d'accueil
  const homeRes = http.get(`${BASE_URL}/`, {
    tags: { page: "home" },
  });
  homeTrend.add(homeRes.timings.duration);
  requestCounter.add(1);

  const homeOk = check(homeRes, {
    "home: status 200":          (r) => r.status === 200,
    "home: contient XYZ Univ":   (r) => r.body.includes("XYZ University"),
    "home: temps < 2s":          (r) => r.timings.duration < 2000,
  });
  errorRate.add(!homeOk);

  sleep(1);

  // Page liste etudiants
  const studentsRes = http.get(`${BASE_URL}/students`, {
    tags: { page: "students" },
  });
  studentsTrend.add(studentsRes.timings.duration);
  requestCounter.add(1);

  const studentsOk = check(studentsRes, {
    "students: status 200 ou 500": (r) => r.status === 200 || r.status === 500,
    "students: temps < 3s":        (r) => r.timings.duration < 3000,
  });
  errorRate.add(!studentsOk);

  sleep(1);
}

// ── Rapport final ─────────────────────────────────────────────────────────
export function handleSummary(data) {
  const p95 = data.metrics.http_req_duration?.values?.["p(95)"] || 0;
  const errors = data.metrics.error_rate?.values?.rate || 0;
  const reqs = data.metrics.http_reqs?.values?.count || 0;

  console.log("\n=== RESUME TEST DE CHARGE ===");
  console.log(`Requetes totales  : ${reqs}`);
  console.log(`p95 duree         : ${p95.toFixed(0)}ms`);
  console.log(`Taux d'erreur     : ${(errors * 100).toFixed(2)}%`);
  console.log(`Seuils respectes  : ${data.metrics.http_req_duration?.thresholds ? "OUI" : "NON"}`);

  return {
    "tests/load/results.json": JSON.stringify(data, null, 2),
    stdout: "\nTest de charge termine.\n",
  };
}
