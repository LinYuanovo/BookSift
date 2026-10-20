#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <sys/stat.h>
#include <unistd.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

namespace {

void HandleUpdateMethodCall(
    FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
  g_autoptr(FlMethodResponse) response = nullptr;
  if (strcmp(fl_method_call_get_name(method_call), "installPackage") != 0) {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }
  FlValue* arguments = fl_method_call_get_args(method_call);
  if (fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP) {
    response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("bad_args", "arguments missing", nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }
  FlValue* path_value = fl_value_lookup_string(arguments, "path");
  if (path_value == nullptr ||
      fl_value_get_type(path_value) != FL_VALUE_TYPE_STRING) {
    response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("bad_args", "path missing", nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }
  const gchar* archive = fl_value_get_string(path_value);
  g_autoptr(GError) temp_error = nullptr;
  g_autofree gchar* temp_dir =
      g_dir_make_tmp("booksift-update.XXXXXX", &temp_error);
  if (temp_dir == nullptr) {
    response = FL_METHOD_RESPONSE(fl_method_error_response_new(
        "update_failed",
        temp_error != nullptr ? temp_error->message : "temp dir failed",
        nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }
  g_autofree gchar* executable =
      g_file_read_link("/proc/self/exe", nullptr);
  if (executable == nullptr) {
    response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("update_failed", "bundle missing", nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }
  g_autofree gchar* bundle = g_path_get_dirname(executable);
  g_autofree gchar* script =
      g_build_filename(bundle, "data", "update", "booksift_updater.sh", nullptr);
  if (!g_file_test(script, G_FILE_TEST_IS_REGULAR)) {
    response = FL_METHOD_RESPONSE(fl_method_error_response_new(
        "update_failed", "update helper missing", nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }
  g_autofree gchar* helper =
      g_build_filename(temp_dir, "booksift_updater.sh", nullptr);
  g_autofree gchar* script_contents = nullptr;
  g_autoptr(GError) copy_error = nullptr;
  if (!g_file_get_contents(script, &script_contents, nullptr, &copy_error) ||
      !g_file_set_contents(helper, script_contents, -1, &copy_error)) {
    response = FL_METHOD_RESPONSE(fl_method_error_response_new(
        "update_failed",
        copy_error != nullptr ? copy_error->message : "helper copy failed",
        nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }
  if (chmod(helper, 0755) != 0) {
    response = FL_METHOD_RESPONSE(fl_method_error_response_new(
        "update_failed", "helper permission failed", nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }
  g_autofree gchar* pid = g_strdup_printf("%d", getpid());
  const gchar* argv[] = {"/bin/sh", helper, archive, bundle, pid, nullptr};
  g_autoptr(GError) error = nullptr;
  if (!g_spawn_async(bundle, const_cast<gchar**>(argv), nullptr,
                     G_SPAWN_DO_NOT_REAP_CHILD | G_SPAWN_SEARCH_PATH, nullptr,
                     nullptr, nullptr, nullptr, &error)) {
    response = FL_METHOD_RESPONSE(fl_method_error_response_new(
        "update_failed", error != nullptr ? error->message : "spawn failed",
        nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }
  response = FL_METHOD_RESPONSE(fl_method_success_response_new(
      fl_value_new_bool(TRUE)));
  fl_method_call_respond(method_call, response, nullptr);
  g_application_quit(G_APPLICATION(user_data));
}

}  // namespace

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    // 窗口标题 = 应用中文名「扫书汇」；用 \u 转义保持源码纯 ASCII，
    // 与 windows/runner/main.cpp 的口径一致。
    gtk_header_bar_set_title(header_bar, "\u626B\u4E66\u6C47");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "\u626B\u4E66\u6C47");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  FlPluginRegistry* registry = FL_PLUGIN_REGISTRY(view);
  fl_register_plugins(registry);
  FlEngine* engine = fl_view_get_engine(view);
  FlMethodChannel* update_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(engine), "booksift/update",
      FL_METHOD_CODEC(fl_standard_method_codec_new()));
  g_object_ref_sink(update_channel);
  fl_method_channel_set_method_call_handler(
      update_channel, HandleUpdateMethodCall, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
