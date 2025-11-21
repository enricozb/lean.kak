/// Logs a trace to the global kakoune logger. [`logging::init`] must first be
/// called to initialize the global logger.
#[macro_export]
macro_rules! trace {
    ($($arg:tt)*) => {{
        let _ = $crate::logging::KAKOUNE_LOGGER
            .log(
                $crate::logging::Level::Trace,
                ::std::format!($($arg)*),
            )
            .await
            .expect("trace logging statement failed")
    }};
}

/// Logs a debug to the global kakoune logger. [`logging::init`] must first be
/// called to initialize the global logger.
#[macro_export]
macro_rules! debug {
    ($($arg:tt)*) => {{
        let _ = $crate::logging::KAKOUNE_LOGGER
            .log(
                $crate::logging::Level::Debug,
                ::std::format!($($arg)*),
            )
            .await
            .expect("debug logging statement failed")
    }};
}

/// Logs a info to the global kakoune logger. [`logging::init`] must first be
/// called to initialize the global logger.
#[macro_export]
macro_rules! info {
    ($($arg:tt)*) => {{
        let _ = $crate::logging::KAKOUNE_LOGGER
            .log(
                $crate::logging::Level::Info,
                ::std::format!($($arg)*),
            )
            .await
            .expect("info logging statement failed")
    }};
}

/// Logs a warn to the global kakoune logger. [`logging::init`] must first be
/// called to initialize the global logger.
#[macro_export]
macro_rules! warn {
    ($($arg:tt)*) => {{
        let _ = $crate::logging::KAKOUNE_LOGGER
            .log(
                $crate::logging::Level::Warn,
                ::std::format!($($arg)*),
            )
            .await
            .expect("warn logging statement failed")
    }};
}

/// Logs a error to the global kakoune logger. [`logging::init`] must first be
/// called to initialize the global logger.
#[macro_export]
macro_rules! error {
    ($($arg:tt)*) => {{
        let _ = $crate::logging::KAKOUNE_LOGGER
            .log(
                $crate::logging::Level::Error,
                ::std::format!($($arg)*),
            )
            .await
            .expect("error logging statement failed")
    }};
}
