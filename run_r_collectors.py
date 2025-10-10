#!/usr/bin/env python3
# ============================================
# EkstradataCollector/collectors/run_r_collectors.py
# Python Orchestrator for R Data Collection Scripts
# Version: 3.0 - FINAL WORKING VERSION
# ============================================

import subprocess
import os
import sys
import json
import datetime
import time
import logging
from pathlib import Path
from typing import Dict, List, Optional

# Wymuszenie UTF-8 dla Windows
if sys.platform == 'win32':
    import locale
    if locale.getpreferredencoding().upper() != 'UTF-8':
        os.environ['PYTHONIOENCODING'] = 'utf-8'
    # Windows Console UTF-8
    os.system('chcp 65001 > nul 2>&1')

try:
    from dotenv import load_dotenv
except ImportError:
    print("⚠️  Instaluję python-dotenv...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "python-dotenv", "-q"])
    from dotenv import load_dotenv

# ============================================
# KONFIGURACJA
# ============================================

class Config:
    """Centralna konfiguracja projektu"""
    
    BASE_DIR = Path(__file__).parent
    COLLECTORS_DIR = BASE_DIR / "collectors"
    R_SCRIPTS_DIR = BASE_DIR / "r_scripts"
    DATA_DIR = BASE_DIR / "data"
    CONFIG_DIR = BASE_DIR / "config"
    LOGS_DIR = BASE_DIR / "logs"
    ARCHIVE_DIR = BASE_DIR / "archive"
    
    ENV_FILE = CONFIG_DIR / ".env"
    
    SCRIPT_TIMEOUT = 300
    RETRY_ATTEMPTS = 2
    DELAY_BETWEEN_SCRIPTS = 3
    
    R_SCRIPTS = [
        {'name': '01_collect_matches.R', 'description': 'Wyniki meczów z FBref', 'output_files': ['match_results.json'], 'critical': True},
        {'name': '02_collect_standings.R', 'description': 'Tabela ligowa z FBref', 'output_files': ['standings.json'], 'critical': True},
        {'name': '03_collect_xg.R', 'description': 'Statystyki xG z FBref', 'output_files': ['xg.json'], 'critical': False},
        {'name': '04_collect_players.R', 'description': 'Wartości zawodników z Transfermarkt', 'output_files': ['players.json'], 'critical': True},
        {'name': '05_collect_transfers.R', 'description': 'Transfery z Transfermarkt', 'output_files': ['transfers.json'], 'critical': False},
        {'name': '06_collect_injuries.R', 'description': 'Kontuzje z Transfermarkt', 'output_files': ['injuries.json'], 'critical': False},
        {'name': '07_collect_form.R', 'description': 'Forma drużyn (L5)', 'output_files': ['form.json'], 'critical': False},
        {'name': '08_collect_contracts.R', 'description': 'Kontrakty zawodników', 'output_files': ['contracts.json'], 'critical': False},
        {'name': '09_collect_nationalities.R', 'description': 'Statystyki narodowości', 'output_files': ['nationalities.json'], 'critical': False},
        {'name': '10_collect_suspensions.R', 'description': 'Zawieszenia zawodników', 'output_files': ['suspensions.json'], 'critical': False},
        {'name': '11_collect_young_talents.R', 'description': 'Młode talenty (≤21 lat)', 'output_files': ['young_talents.json'], 'critical': False},
        {'name': '12_collect_league_value_trend.R', 'description': 'Trend wartości ligi', 'output_files': ['league_value_trend.json', 'ekstraklasa_clubs_cache.json'], 'critical': False}
    ]

# ============================================
# LOGGING
# ============================================

def setup_logging() -> logging.Logger:
    """Konfiguracja loggera"""
    Config.LOGS_DIR.mkdir(parents=True, exist_ok=True)
    
    log_file = Config.LOGS_DIR / f'collector_{datetime.datetime.now().strftime("%Y%m%d")}.log'
    
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s', datefmt='%Y-%m-%d %H:%M:%S')
    
    file_handler = logging.FileHandler(log_file, encoding='utf-8')
    file_handler.setFormatter(formatter)
    file_handler.setLevel(logging.DEBUG)
    
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    console_handler.setLevel(logging.INFO)
    
    logger = logging.getLogger('EkstraklasaCollector')
    logger.setLevel(logging.DEBUG)
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    
    return logger

logger = setup_logging()

# ============================================
# FUNKCJE POMOCNICZE
# ============================================

def load_environment():
    """Ładuje .env"""
    if Config.ENV_FILE.exists():
        load_dotenv(Config.ENV_FILE)
        logger.info(f"✅ Załadowano konfigurację z {Config.ENV_FILE}")
    else:
        logger.warning("⚠️ Brak .env - tworzę domyślny...")
        create_default_env()
        load_dotenv(Config.ENV_FILE)

def create_default_env():
    """Tworzy domyślny .env"""
    Config.CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    
    default_env = """# Ekstraklasa Data Collector
import platform

# Wybór Rscript zależnie od systemu
if platform.system() == "Windows":
    R_SCRIPT_PATH = r"C:\Program Files\R\R-4.5.1\bin\x64\Rscript.exe"
else:
    R_SCRIPT_PATH = "Rscript"

SEASON_START=2025
SEASON_END=2026
LEAGUE_COUNTRY=Poland
LEAGUE_URL=https://www.transfermarkt.com/ekstraklasa/startseite/wettbewerb/PL1
REQUEST_DELAY=3
MAX_RETRIES=2
"""
    with open(Config.ENV_FILE, 'w', encoding='utf-8') as f:
        f.write(default_env)
    logger.info(f"💾 Utworzono {Config.ENV_FILE}")

def get_r_path() -> str:
    """Pobiera ścieżkę do Rscript"""
    r_path = os.getenv('R_PATH')
    
    if not r_path:
        if sys.platform == 'win32':
            possible_paths = [
                r"C:\Program Files\R\R-4.5.1\bin\x64\Rscript.exe",
                r"C:\Program Files\R\R-4.4.2\bin\x64\Rscript.exe",
                r"C:\Program Files\R\R-4.4.0\bin\x64\Rscript.exe",
            ]
            for path in possible_paths:
                if os.path.exists(path):
                    r_path = path
                    break
            else:
                r_path = "Rscript.exe"
        else:
            r_path = "/usr/bin/Rscript"
            if not os.path.exists(r_path):
                r_path = "Rscript"
    
    return r_path

def verify_r_installation(r_path: str) -> bool:
    """Weryfikuje R"""
    try:
        result = subprocess.run([r_path, "--version"], capture_output=True, text=True, timeout=10, encoding='utf-8', errors='ignore')
        
        if result.returncode == 0:
            version = result.stdout.split('\n')[0]
            logger.info(f"✅ R: {version}")
            return True
        else:
            logger.error(f"❌ R błąd: {result.stderr}")
            return False
    except:
        logger.error(f"❌ Nie znaleziono R: {r_path}")
        return False

def archive_file(filename: str) -> bool:
    """Archiwizuje plik"""
    source = Config.DATA_DIR / filename
    if not source.exists():
        return False
    
    Config.ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    archived_name = f"{source.stem}_{timestamp}{source.suffix}"
    destination = Config.ARCHIVE_DIR / archived_name
    
    try:
        import shutil
        shutil.copy2(source, destination)
        logger.debug(f"📦 Zarchiwizowano: {filename}")
        return True
    except:
        return False

def verify_output_file(filename: str) -> Dict:
    """Weryfikuje plik JSON"""
    filepath = Config.DATA_DIR / filename
    
    if not filepath.exists():
        return {'exists': False, 'valid': False, 'records': 0, 'error': 'Brak pliku'}
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        records = len(data) if isinstance(data, list) else 1
        return {'exists': True, 'valid': True, 'records': records}
    except:
        return {'exists': True, 'valid': False, 'records': 0, 'error': 'Błąd JSON'}

# ============================================
# EXECUTOR
# ============================================

class RScriptExecutor:
    """Executor skryptów R"""
    
    def __init__(self, r_path: str):
        self.r_path = r_path
        self.results = []
    
    def run_script(self, script_info: Dict, attempt: int = 1) -> Dict:
        """Uruchamia skrypt R"""
        script_name = script_info['name']
        script_path = Config.R_SCRIPTS_DIR / script_name
        
        if not script_path.exists():
            logger.error(f"❌ Brak: {script_path}")
            return {'script': script_name, 'success': False, 'error': 'Brak pliku', 'attempt': attempt}
        
        for output_file in script_info.get('output_files', []):
            archive_file(output_file)
        
        logger.info(f"▶ [{attempt}/{Config.RETRY_ATTEMPTS}] {script_info['description']}")
        
        start_time = datetime.datetime.now()
        
        try:
            # Uruchom R (NAJPROSTSZE ROZWIĄZANIE)
            process = subprocess.Popen(
                [self.r_path, str(script_path)],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                cwd=str(Config.BASE_DIR)
            )
            
            try:
                stdout_bytes, stderr_bytes = process.communicate(timeout=Config.SCRIPT_TIMEOUT)
                
                # Dekoduj output - ignoruj błędy encoding
                stdout = stdout_bytes.decode('utf-8', errors='ignore').strip()
                stderr = stderr_bytes.decode('utf-8', errors='ignore').strip()
                
            except subprocess.TimeoutExpired:
                process.kill()
                logger.error(f"⏱️ Timeout: {script_name}")
                return {'script': script_name, 'success': False, 'error': 'Timeout', 'attempt': attempt}
            
            duration = (datetime.datetime.now() - start_time).total_seconds()
            
            # Loguj output
            if stdout:
                for line in stdout.split('\n'):
                    if line.strip():
                        logger.info(f"   R: {line}")
            
            if stderr and process.returncode != 0:
                logger.error(f"   R stderr: {stderr}")
            
            # Sprawdź sukces
            if process.returncode != 0:
                logger.error(f"❌ Kod błędu: {process.returncode}")
                return {'script': script_name, 'success': False, 'returncode': process.returncode, 'duration': duration, 'attempt': attempt}
            
            # Weryfikuj pliki
            output_status = {}
            all_valid = True
            
            for output_file in script_info.get('output_files', []):
                status = verify_output_file(output_file)
                output_status[output_file] = status
                
                if status['valid']:
                    logger.info(f"   ✅ {output_file}: {status['records']} rekordów")
                else:
                    logger.error(f"   ❌ {output_file}: {status.get('error')}")
                    all_valid = False
            
            if all_valid:
                logger.info(f"✅ {script_name} - sukces ({duration:.1f}s)")
            else:
                logger.warning(f"⚠️ {script_name} - błędy")
            
            return {'script': script_name, 'success': all_valid, 'returncode': process.returncode, 'duration': duration, 'output_files': output_status, 'attempt': attempt}
            
        except Exception as e:
            logger.error(f"❌ Wyjątek: {e}")
            return {'script': script_name, 'success': False, 'error': str(e), 'attempt': attempt}
    
    def run_script_with_retry(self, script_info: Dict) -> Dict:
        """Uruchamia z retry"""
        for attempt in range(1, Config.RETRY_ATTEMPTS + 1):
            result = self.run_script(script_info, attempt)
            
            if result['success']:
                self.results.append(result)
                return result
            
            if script_info.get('critical') and attempt < Config.RETRY_ATTEMPTS:
                logger.warning(f"⚠️ Retry za 10s...")
                time.sleep(10)
            else:
                break
        
        self.results.append(result)
        return result
    
    def run_all_scripts(self) -> Dict:
        """Uruchamia wszystkie skrypty"""
        logger.info("=" * 70)
        logger.info("🚀 EKSTRAKLASA DATA COLLECTION - START")
        logger.info(f"   Skrypty: {len(Config.R_SCRIPTS)}")
        logger.info("=" * 70)
        
        start_time = datetime.datetime.now()
        successful = 0
        failed = 0
        critical_failed = []
        
        for i, script_info in enumerate(Config.R_SCRIPTS, 1):
            logger.info(f"\n[{i}/{len(Config.R_SCRIPTS)}] {script_info['name']}")
            
            result = self.run_script_with_retry(script_info)
            
            if result['success']:
                successful += 1
            else:
                failed += 1
                if script_info.get('critical'):
                    critical_failed.append(script_info['name'])
            
            if i < len(Config.R_SCRIPTS):
                time.sleep(Config.DELAY_BETWEEN_SCRIPTS)
        
        total_duration = (datetime.datetime.now() - start_time).total_seconds()
        
        logger.info("\n" + "=" * 70)
        logger.info("📊 PODSUMOWANIE")
        logger.info("=" * 70)
        logger.info(f"✅ Sukces: {successful}/{len(Config.R_SCRIPTS)}")
        logger.info(f"❌ Błędy: {failed}/{len(Config.R_SCRIPTS)}")
        logger.info(f"⏱️ Czas: {total_duration:.1f}s")
        
        if critical_failed:
            logger.error(f"🚨 KRYTYCZNE: {', '.join(critical_failed)}")
        
        logger.info("=" * 70)
        
        return {
            'total_scripts': len(Config.R_SCRIPTS),
            'successful': successful,
            'failed': failed,
            'critical_failed': critical_failed,
            'duration': total_duration,
            'results': self.results,
            'timestamp': datetime.datetime.now().isoformat()
        }
    
    def save_execution_report(self, summary: Dict):
        """Zapisuje raport"""
        report_file = Config.DATA_DIR / 'execution_report.json'
        
        try:
            with open(report_file, 'w', encoding='utf-8') as f:
                json.dump(summary, f, indent=2, ensure_ascii=False)
            logger.info(f"💾 Raport: {report_file}")
        except Exception as e:
            logger.error(f"❌ Błąd raportu: {e}")

# ============================================
# MAIN
# ============================================

def main():
    """Main"""
    print("\n" + "=" * 70)
    print("🏆 EKSTRAKLASA DATA COLLECTOR v3.0 - FINAL")
    print("=" * 70 + "\n")
    
    try:
        load_environment()
        
        r_path = get_r_path()
        logger.info(f"🔧 R: {r_path}")
        
        if not verify_r_installation(r_path):
            logger.error("❌ R niedostępne")
            return 1
        
        for directory in [Config.DATA_DIR, Config.LOGS_DIR, Config.ARCHIVE_DIR, Config.R_SCRIPTS_DIR]:
            directory.mkdir(parents=True, exist_ok=True)
        
        missing_scripts = []
        for script_info in Config.R_SCRIPTS:
            script_path = Config.R_SCRIPTS_DIR / script_info['name']
            if not script_path.exists():
                missing_scripts.append(script_info['name'])
        
        if missing_scripts:
            logger.error(f"❌ Brak {len(missing_scripts)} skryptów R:")
            for script in missing_scripts:
                logger.error(f"   - {script}")
            return 1
        
        executor = RScriptExecutor(r_path)
        summary = executor.run_all_scripts()
        executor.save_execution_report(summary)
        
        if summary['critical_failed']:
            logger.error("\n❌ KRYTYCZNE BŁĘDY")
            return 1
        elif summary['failed'] > 0:
            logger.warning("\n⚠️ Częściowy sukces")
            return 0
        else:
            logger.info("\n✅ SUKCES - wszystkie dane zebrane!")
            logger.info(f"📁 Dane: {Config.DATA_DIR}")
            return 0
        
    except KeyboardInterrupt:
        logger.warning("\n⚠️ Przerwano (Ctrl+C)")
        return 130
    except Exception as e:
        logger.error(f"\n❌ BŁĄD: {e}", exc_info=True)
        return 1

if __name__ == "__main__":
    sys.exit(main())
