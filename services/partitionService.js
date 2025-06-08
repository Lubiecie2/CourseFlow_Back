const cron = require("node-cron");
const partitionModel = require("../models/partitionModel");

class PartitionService {
  constructor() {
    this.job = null;
    this.tables = ["user_logs", "course_logs"];
  }

  startScheduler() {
    this.job = cron.schedule("0 1 1 * *", () => {
      this.runMaintenance();
    });

    console.log("Uruchomiono scheduler zarządzania partycjami");

    this.runNow();
  }

  stopScheduler() {
    if (this.job) {
      this.job.stop();
      console.log("Zatrzymano scheduler zarządzania partycjami");
    }
  }

  async runNow() {
    console.log(
      `[${new Date().toISOString()}] Uruchamianie zarządzania partycjami teraz...`
    );
    try {
      await this.runMaintenance();
    } catch (error) {
      console.error("Błąd podczas zarządzania partycjami:", error);
    }
  }

  async runMaintenance() {
    try {
      for (const table of this.tables) {
        console.log(`Rozpoczęto zarządzanie partycjami dla tabeli ${table}`);

        const results = await partitionModel.preparePartitions(table, 2);

        console.log(`Wyniki zarządzania partycjami dla ${table}:`, results);
      }

      console.log(
        `[${new Date().toISOString()}] Zarządzanie partycjami zakończone powodzeniem`
      );
      return true;
    } catch (error) {
      console.error(
        `[${new Date().toISOString()}] Błąd podczas zarządzania partycjami:`,
        error
      );
      return false;
    }
  }
}

module.exports = new PartitionService();
